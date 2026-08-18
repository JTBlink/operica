package handler

import (
	"testing"

	"github.com/JTBlink/operica/server/internal/auth"
	db "github.com/JTBlink/operica/server/pkg/db/generated"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func TestIssueJWT_AutoLoginUserHasNoExpiry(t *testing.T) {
	t.Setenv("APP_ENV", "development")
	t.Setenv("AUTO_LOGIN_EMAIL", "operica@operica.local")

	tokenString, err := (&Handler{}).issueJWT(db.User{
		ID:    pgtype.UUID{Bytes: [16]byte{1}, Valid: true},
		Email: "OPERICA@OPERICA.LOCAL",
	})
	if err != nil {
		t.Fatalf("issueJWT: %v", err)
	}

	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
		return auth.JWTSecret(), nil
	})
	if err != nil || !token.Valid {
		t.Fatalf("parse JWT: valid=%v err=%v", token.Valid, err)
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		t.Fatalf("claims type = %T, want jwt.MapClaims", token.Claims)
	}
	if _, ok := claims["exp"]; ok {
		t.Fatalf("auto-login JWT unexpectedly has exp claim: %v", claims["exp"])
	}
}

func TestIssueJWT_NonAutoLoginUserExpires(t *testing.T) {
	t.Setenv("APP_ENV", "development")
	t.Setenv("AUTO_LOGIN_EMAIL", "operica@operica.local")

	tokenString, err := (&Handler{}).issueJWT(db.User{
		ID:    pgtype.UUID{Bytes: [16]byte{1}, Valid: true},
		Email: "other@example.com",
	})
	if err != nil {
		t.Fatalf("issueJWT: %v", err)
	}

	claims := jwt.MapClaims{}
	if _, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
		return auth.JWTSecret(), nil
	}); err != nil {
		t.Fatalf("parse JWT: %v", err)
	}
	if _, ok := claims["exp"]; !ok {
		t.Fatal("regular JWT is missing exp claim")
	}
}

func TestIssueJWT_AutoLoginUserExpiresInProduction(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("AUTO_LOGIN_EMAIL", "operica@operica.local")

	tokenString, err := (&Handler{}).issueJWT(db.User{
		ID:    pgtype.UUID{Bytes: [16]byte{1}, Valid: true},
		Email: "operica@operica.local",
	})
	if err != nil {
		t.Fatalf("issueJWT: %v", err)
	}

	claims := jwt.MapClaims{}
	if _, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
		return auth.JWTSecret(), nil
	}); err != nil {
		t.Fatalf("parse JWT: %v", err)
	}
	if _, ok := claims["exp"]; !ok {
		t.Fatal("production auto-login JWT is missing exp claim")
	}
}
