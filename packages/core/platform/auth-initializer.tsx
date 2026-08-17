"use client";

import { useEffect, type ReactNode } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { ApiError, getApi } from "../api";
import { useAuthStore } from "../auth";
import {
  captureSignupSource,
  identify as identifyAnalytics,
  initAnalytics,
  resetAnalytics,
} from "../analytics";
import { configStore } from "../config";
import { workspaceKeys } from "../workspace/queries";
import { createLogger } from "../logger";
import { defaultStorage } from "./storage";
import { setCurrentWorkspace } from "./workspace-storage";
import type { ClientIdentity } from "./types";
import type { StorageAdapter } from "../types/storage";
import type { User } from "../types";

const logger = createLogger("auth");

export function AuthInitializer({
  children,
  onLogin,
  onLogout,
  storage = defaultStorage,
  cookieAuth,
  identity,
}: {
  children: ReactNode;
  onLogin?: () => void;
  onLogout?: () => void;
  storage?: StorageAdapter;
  cookieAuth?: boolean;
  identity?: ClientIdentity;
}) {
  const qc = useQueryClient();

  useEffect(() => {
    const api = getApi();

    // Stamp attribution before anything else — the signup event (server-side)
    // reads this cookie, so it has to be present before the user hits submit.
    captureSignupSource();

    // Fetch app config (CDN domain, PostHog key, …) in the background — non-blocking.
    api
      .getConfig()
      .then((cfg) => {
        if (cfg.cdn_domain) {
          configStore.getState().setCdnConfig({
            cdnDomain: cfg.cdn_domain,
            // Old servers omit this — false keeps the previous behavior.
            cdnSigned: cfg.cdn_signed === true,
          });
        }
        configStore.getState().setAuthConfig({
          allowSignup: cfg.allow_signup,
          googleClientId: cfg.google_client_id,
          // Old servers omit this field — treat that as "creation allowed"
          // (the managed-cloud default) rather than blocking the UI.
          workspaceCreationDisabled: cfg.workspace_creation_disabled === true,
          // Absent/false on the managed cloud and older servers → section hidden.
          vcsIntegrationAvailable: cfg.vcs_integration_available === true,
        });
        configStore.getState().setDaemonConfig({
          daemonServerUrl: cfg.daemon_server_url,
          daemonAppUrl: cfg.daemon_app_url,
        });
        configStore.getState().setFeatureFlags(cfg.feature_flags);
        configStore.getState().setServerVersion(cfg.server_version);
        if (cfg.posthog_key) {
          initAnalytics({
            key: cfg.posthog_key,
            host: cfg.posthog_host || "",
            appVersion: identity?.version,
            environment: cfg.analytics_environment,
          });
        }
      })
      .catch(() => {
        /* config is optional — legacy file card matching degrades gracefully */
      });

    const onAuthSuccess = (user: User) => {
      onLogin?.();
      useAuthStore.setState({ user, isLoading: false });
      identifyAnalytics(user.id, { email: user.email, name: user.name });
    };

    const onAuthFailure = () => {
      onLogout?.();
      resetAnalytics();
      useAuthStore.setState({ user: null, isLoading: false });
    };

    if (cookieAuth) {
      // Cookie mode: the HttpOnly cookie is sent automatically by the browser.
      // Call the API to check if the session is still valid.
      //
      // Seed the workspace list into React Query so the URL-driven layout can
      // resolve the slug without a second fetch. The active workspace itself
      // is derived from the URL by [workspaceSlug]/layout.tsx — no imperative
      // selection here.
      Promise.all([api.getMe(), api.listWorkspaces()])
        .then(([user, wsList]) => {
          onAuthSuccess(user);
          qc.setQueryData(workspaceKeys.list(), wsList);
        })
        .catch((err) => {
          logger.error("cookie auth init failed", err);
          onAuthFailure();
        });
      return;
    }

    // Token mode: read from localStorage (Electron / legacy). Desktop local
    // development may have AUTO_LOGIN_EMAIL configured on the server. That
    // bypass authenticates requests with no bearer token, but the daemon still
    // needs a real JWT so it can mint its own PAT. Bootstrap that JWT through
    // the existing CLI-token endpoint before the normal user/workspace fetch.
    const tryDesktopAutoLogin = async (): Promise<boolean> => {
      if (identity?.platform !== "desktop" || storage.getItem("operica_token")) {
        return false;
      }
      try {
        const result = await api.issueCliToken();
        storage.setItem("operica_token", result.token);
        api.setToken(result.token);
        return true;
      } catch (err) {
        // A 401 means AUTO_LOGIN_EMAIL is not enabled (normal production
        // behavior). Other failures are still allowed to fall through to the
        // standard auth path, which will surface the real server/network error.
        if (!(err instanceof ApiError && err.status === 401)) {
          logger.debug("desktop auto-login token unavailable", {
            error: err instanceof Error ? err.message : String(err),
          });
        }
        return false;
      }
    };

    const initializeTokenMode = async (): Promise<void> => {
      let token = storage.getItem("operica_token");
      if (!token) await tryDesktopAutoLogin();
      token = storage.getItem("operica_token");
      if (token) api.setToken(token);

      try {
        const [user, wsList] = await Promise.all([api.getMe(), api.listWorkspaces()]);
        onAuthSuccess(user);
        // Seed React Query cache so the URL-driven layout can resolve the
        // slug without a second fetch.
        qc.setQueryData(workspaceKeys.list(), wsList);
      } catch (err) {
        // A stale Desktop JWT is common after a local backend reset. Clear it,
        // mint the dev auto-login JWT once, and retry the same authoritative
        // reads before falling back to the normal logged-out state.
        if (
          identity?.platform === "desktop" &&
          err instanceof ApiError &&
          err.status === 401
        ) {
          api.setToken(null);
          storage.removeItem("operica_token");
          if (await tryDesktopAutoLogin()) {
            try {
              const [user, wsList] = await Promise.all([
                api.getMe(),
                api.listWorkspaces(),
              ]);
              onAuthSuccess(user);
              qc.setQueryData(workspaceKeys.list(), wsList);
              return;
            } catch (retryErr) {
              logger.error("auth retry failed", retryErr);
            }
          }
        }
        logger.error("auth init failed", err);
        api.setToken(null);
        setCurrentWorkspace(null, null);
        storage.removeItem("operica_token");
        onAuthFailure();
      }
    };

    void initializeTokenMode();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return <>{children}</>;
}
