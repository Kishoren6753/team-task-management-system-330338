# PostgreSQL schema & seed data (team task management)

This container uses PostgreSQL with the connection command stored in `db_connection.txt`.

## Connect / run statements (CLI)

Use the connection command exactly as stored in `db_connection.txt` and execute SQL **one statement at a time**:

```bash
# From this folder (team-task-management-system-330338/postgresql_db)
CONN="$(cat db_connection.txt)"

# Example: run one statement
$CONN -c "SELECT 1;"
```

> Note: When using `DO $$ ... $$;` blocks with `psql -c`, you must escape the dollar quotes for the shell:
>
> `-c "DO \$\$ BEGIN ... END \$\$;"`

## Entities

### users
- Stores user accounts (for backend auth + display).
- Email is enforced lowercase (`CHECK (email = lower(email))`) and a functional unique index ensures case-insensitive uniqueness.

Key fields:
- `id uuid PK`
- `email text UNIQUE`
- `password_hash text`
- `full_name text`
- `is_active boolean`

### projects
- Projects belong to an owner (`owner_user_id`).
- Basic status constraint: `active` or `archived`.

Key fields:
- `id uuid PK`
- `owner_user_id uuid FK -> users(id)`
- `name`, `description`, `status`

### project_members
- Many-to-many membership between users and projects.
- Composite primary key `(project_id, user_id)`.

Key fields:
- `project_id uuid FK -> projects(id)`
- `user_id uuid FK -> users(id)`
- `role project_member_role`

### tasks
- Tasks belong to a project and are created by a user.
- Can optionally be assigned to a user.
- Uses enums for `status` and `priority`.
- Date check ensures `due_date >= start_date` when both are present.

Key fields:
- `project_id uuid FK -> projects(id)`
- `created_by_user_id uuid FK -> users(id)`
- `assigned_to_user_id uuid nullable FK -> users(id)`
- `status task_status`, `priority task_priority`

## Enums

- `task_status`: `todo`, `in_progress`, `blocked`, `done`, `archived`
- `task_priority`: `low`, `medium`, `high`, `urgent`
- `project_member_role`: `owner`, `admin`, `member`, `viewer`

## Indexes

- `users`: `uq_users_email_lower` on `lower(email)` (case-insensitive uniqueness)
- `projects`: `idx_projects_owner_user_id`
- `project_members`: `idx_project_members_user_id`
- `tasks`: `idx_tasks_project_id`, `idx_tasks_assigned_to_user_id`, `idx_tasks_status`, `idx_tasks_due_date`

## Seed data

Deterministic UUIDs are used so seeds are stable and can be referenced.

Users:
- Alice (id `...0001`)
- Bob (id `...0002`)
- Carol (id `...0003`)

Projects:
- Website Redesign (id `...0001`)
- API Stabilization (id `...0002`)

Memberships & tasks are seeded to demonstrate:
- owner/admin/member/viewer roles
- assigned/unassigned tasks
- multiple statuses/priorities
- completed task with `completed_at`

> The seed `password_hash` values are placeholders meant for development/demo. Replace with real bcrypt hashes when wiring up authentication.
