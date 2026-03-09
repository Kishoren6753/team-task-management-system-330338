#!/bin/bash
set -euo pipefail

# Applies schema + seed data using the connection command in db_connection.txt.
# IMPORTANT: executes statements one at a time via psql -c, as required.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONN_CMD="$(cat "${ROOT_DIR}/db_connection.txt")"

run_sql() {
  local sql="$1"
  echo "==> ${sql}"
  # shellcheck disable=SC2086
  ${CONN_CMD} -c "${sql}"
}

# Extensions (for UUID generation)
run_sql "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# Enums (created idempotently)
run_sql "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN CREATE TYPE task_status AS ENUM ('todo','in_progress','blocked','done','archived'); END IF; END \$\$;"
run_sql "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_priority') THEN CREATE TYPE task_priority AS ENUM ('low','medium','high','urgent'); END IF; END \$\$;"
run_sql "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'project_member_role') THEN CREATE TYPE project_member_role AS ENUM ('owner','admin','member','viewer'); END IF; END \$\$;"

# Tables
run_sql "CREATE TABLE IF NOT EXISTS users (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL UNIQUE, password_hash text NOT NULL, full_name text NOT NULL, avatar_url text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), last_login_at timestamptz, is_active boolean NOT NULL DEFAULT true, CONSTRAINT users_email_lowercase_chk CHECK (email = lower(email)));"
run_sql "CREATE TABLE IF NOT EXISTS projects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT, name text NOT NULL, description text, status text NOT NULL DEFAULT 'active', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived_at timestamptz, CONSTRAINT projects_name_len_chk CHECK (char_length(name) BETWEEN 1 AND 200), CONSTRAINT projects_status_chk CHECK (status IN ('active','archived')));"
run_sql "CREATE TABLE IF NOT EXISTS project_members (project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, role project_member_role NOT NULL DEFAULT 'member', joined_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (project_id, user_id));"
run_sql "CREATE TABLE IF NOT EXISTS tasks (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE, created_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT, assigned_to_user_id uuid REFERENCES users(id) ON DELETE SET NULL, title text NOT NULL, description text, status task_status NOT NULL DEFAULT 'todo', priority task_priority NOT NULL DEFAULT 'medium', due_date date, start_date date, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), CONSTRAINT tasks_title_len_chk CHECK (char_length(title) BETWEEN 1 AND 200), CONSTRAINT tasks_dates_chk CHECK (due_date IS NULL OR start_date IS NULL OR due_date >= start_date));"

# Indexes
run_sql "CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email_lower ON users((lower(email)));"
run_sql "CREATE INDEX IF NOT EXISTS idx_projects_owner_user_id ON projects(owner_user_id);"
run_sql "CREATE INDEX IF NOT EXISTS idx_project_members_user_id ON project_members(user_id);"
run_sql "CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);"
run_sql "CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to_user_id ON tasks(assigned_to_user_id);"
run_sql "CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);"
run_sql "CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);"

# Seed users (deterministic IDs)
run_sql "INSERT INTO users (id,email,password_hash,full_name) VALUES ('00000000-0000-0000-0000-000000000001','alice@example.com','\$2b\$10\$examplehashalice','Alice Johnson') ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO users (id,email,password_hash,full_name) VALUES ('00000000-0000-0000-0000-000000000002','bob@example.com','\$2b\$10\$examplehashbob','Bob Smith') ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO users (id,email,password_hash,full_name) VALUES ('00000000-0000-0000-0000-000000000003','carol@example.com','\$2b\$10\$examplehashcarol','Carol Lee') ON CONFLICT (id) DO NOTHING;"

# Seed projects
run_sql "INSERT INTO projects (id,owner_user_id,name,description,status) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Website Redesign','Refresh marketing site UI/UX','active') ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO projects (id,owner_user_id,name,description,status) VALUES ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','API Stabilization','Reduce error rates and improve observability','active') ON CONFLICT (id) DO NOTHING;"

# Seed memberships
run_sql "INSERT INTO project_members (project_id,user_id,role) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','owner') ON CONFLICT (project_id,user_id) DO NOTHING;"
run_sql "INSERT INTO project_members (project_id,user_id,role) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','member') ON CONFLICT (project_id,user_id) DO NOTHING;"
run_sql "INSERT INTO project_members (project_id,user_id,role) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','viewer') ON CONFLICT (project_id,user_id) DO NOTHING;"
run_sql "INSERT INTO project_members (project_id,user_id,role) VALUES ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','owner') ON CONFLICT (project_id,user_id) DO NOTHING;"
run_sql "INSERT INTO project_members (project_id,user_id,role) VALUES ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','admin') ON CONFLICT (project_id,user_id) DO NOTHING;"

# Seed tasks
run_sql "INSERT INTO tasks (id,project_id,created_by_user_id,assigned_to_user_id,title,description,status,priority,due_date,start_date) VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','Create new landing page wireframes','Draft homepage + pricing page wireframes','in_progress','high',current_date + 14,current_date) ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO tasks (id,project_id,created_by_user_id,assigned_to_user_id,title,description,status,priority,due_date,start_date) VALUES ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',NULL,'Audit existing content','Inventory current pages and content gaps','todo','medium',current_date + 7,current_date) ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO tasks (id,project_id,created_by_user_id,assigned_to_user_id,title,description,status,priority,due_date,start_date) VALUES ('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Add request tracing','Instrument Express API with request IDs and timing logs','blocked','urgent',current_date + 10,current_date) ON CONFLICT (id) DO NOTHING;"
run_sql "INSERT INTO tasks (id,project_id,created_by_user_id,assigned_to_user_id,title,description,status,priority,due_date,start_date,completed_at) VALUES ('20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','Review error logs','Review last 7 days of 5xx errors and categorize','done','low',current_date - 1,current_date - 8,now()) ON CONFLICT (id) DO NOTHING;"

# Quick verification output
run_sql "SELECT 'users' AS table, count(*) FROM users UNION ALL SELECT 'projects', count(*) FROM projects UNION ALL SELECT 'project_members', count(*) FROM project_members UNION ALL SELECT 'tasks', count(*) FROM tasks;"

echo "Done."
