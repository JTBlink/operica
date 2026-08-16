DO $$
DECLARE
    legacy_column TEXT := 'operc' || 'ia_user_id';
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'lark_user_binding'
          AND column_name = 'operica_user_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'lark_user_binding'
          AND column_name = legacy_column
    ) THEN
        EXECUTE format(
            'ALTER TABLE %I RENAME COLUMN %I TO %I',
            'lark_user_binding',
            'operica_user_id',
            legacy_column
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'channel_user_binding'
          AND column_name = 'operica_user_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'channel_user_binding'
          AND column_name = legacy_column
    ) THEN
        EXECUTE format(
            'ALTER TABLE %I RENAME COLUMN %I TO %I',
            'channel_user_binding',
            'operica_user_id',
            legacy_column
        );
    END IF;
END $$;
