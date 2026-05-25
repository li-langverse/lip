-- lip registry schema v1 (PH-DB-4 prep)
-- Canonical DDL for the central registry index stored in lidb.
-- Keep in sync with lidb/migrations/001_registry.sql (PH-DB-1).

BEGIN;

CREATE TABLE IF NOT EXISTS publishers (
    id              BIGSERIAL PRIMARY KEY,
    key_id          TEXT NOT NULL UNIQUE,
    public_key      BYTEA NOT NULL,
    display_name    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS packages (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    pkg_id          TEXT,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS package_versions (
    id                  BIGSERIAL PRIMARY KEY,
    package_id          BIGINT NOT NULL REFERENCES packages (id) ON DELETE CASCADE,
    version             TEXT NOT NULL,
    tree_digest         TEXT NOT NULL,
    proof_digest        TEXT NOT NULL,
    coverage_pct        DOUBLE PRECISION NOT NULL CHECK (coverage_pct >= 0 AND coverage_pct <= 100),
    manifest_signature  BYTEA,
    publisher_id        BIGINT REFERENCES publishers (id),
    spdx_license        TEXT,
    changelog_url       TEXT,
    repository_url      TEXT,
    documentation_url   TEXT,
    source_type         TEXT CHECK (source_type IN ('git', 'registry', 'path')),
    source_url          TEXT,
    source_tag          TEXT,
    published_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (package_id, version)
);

CREATE INDEX IF NOT EXISTS idx_package_versions_package_id
    ON package_versions (package_id);

CREATE INDEX IF NOT EXISTS idx_package_versions_published_at
    ON package_versions (published_at DESC);

CREATE TABLE IF NOT EXISTS attestations (
    id                  BIGSERIAL PRIMARY KEY,
    package_version_id  BIGINT NOT NULL REFERENCES package_versions (id) ON DELETE CASCADE,
    attestation_type    TEXT NOT NULL CHECK (attestation_type IN ('ci', 'manual', 'repro')),
    digest              TEXT NOT NULL,
    metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attestations_package_version_id
    ON attestations (package_version_id);

CREATE TABLE IF NOT EXISTS yanks (
    id                  BIGSERIAL PRIMARY KEY,
    package_version_id  BIGINT NOT NULL UNIQUE REFERENCES package_versions (id) ON DELETE CASCADE,
    reason              TEXT NOT NULL,
    yanked_by           BIGINT REFERENCES publishers (id),
    yanked_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS blocklist (
    id              BIGSERIAL PRIMARY KEY,
    block_kind      TEXT NOT NULL CHECK (block_kind IN ('package', 'publisher', 'tree_digest', 'proof_digest')),
    block_value     TEXT NOT NULL,
    reason          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (block_kind, block_value)
);

CREATE INDEX IF NOT EXISTS idx_blocklist_kind_value
    ON blocklist (block_kind, block_value);

-- Active (non-yanked) versions for resolver queries.
CREATE OR REPLACE VIEW registry_active_versions AS
SELECT
    p.name,
    pv.version,
    pv.tree_digest,
    pv.proof_digest,
    pv.coverage_pct,
    pv.manifest_signature,
    pub.key_id AS publisher_key_id,
    pv.spdx_license,
    pv.changelog_url,
    pv.repository_url,
    pv.documentation_url,
    pv.source_type,
    pv.source_url,
    pv.source_tag,
    pv.published_at
FROM package_versions pv
JOIN packages p ON p.id = pv.package_id
LEFT JOIN publishers pub ON pub.id = pv.publisher_id
LEFT JOIN yanks y ON y.package_version_id = pv.id
WHERE y.id IS NULL;

COMMIT;
