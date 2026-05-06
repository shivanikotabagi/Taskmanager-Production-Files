-- ============================================================
-- TaskFlow — MySQL Schema
-- ============================================================
-- This file is auto-executed by the MySQL container on FIRST
-- boot only (via /docker-entrypoint-initdb.d/).

-- Default admin (admin / Admin@123) is seeded by
-- DataInitializer.java on first Spring Boot startup.
-- ============================================================

USE taskmanager_db;

-- ── Users ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(50)  UNIQUE NOT NULL,
    email      VARCHAR(100) UNIQUE NOT NULL,
    password   VARCHAR(255) NOT NULL,
    full_name  VARCHAR(100) NOT NULL,
    role       ENUM('ADMIN','MANAGER','USER') NOT NULL DEFAULT 'USER',
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── Projects ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    description TEXT,
    status      ENUM('PLANNING','ACTIVE','ON_HOLD','COMPLETED','CANCELLED') DEFAULT 'PLANNING',
    priority    ENUM('LOW','MEDIUM','HIGH','CRITICAL') DEFAULT 'MEDIUM',
    start_date  DATE,
    end_date    DATE,
    manager_id  BIGINT,
    created_by  BIGINT NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- ── Project Members ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS project_members (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    project_id  BIGINT NOT NULL,
    user_id     BIGINT NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by BIGINT,
    UNIQUE KEY uq_project_user (project_id, user_id),
    FOREIGN KEY (project_id)  REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)     REFERENCES users(id)    ON DELETE CASCADE,
    FOREIGN KEY (assigned_by) REFERENCES users(id)    ON DELETE SET NULL
);

-- ── Tasks ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    description  TEXT,
    status       ENUM('TODO','IN_PROGRESS','IN_REVIEW','DONE','CANCELLED') DEFAULT 'TODO',
    priority     ENUM('LOW','MEDIUM','HIGH','CRITICAL') DEFAULT 'MEDIUM',
    project_id   BIGINT NOT NULL,
    assigned_to  BIGINT,
    created_by   BIGINT NOT NULL,
    due_date     DATE,
    completed_at TIMESTAMP NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id)  REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id)    ON DELETE SET NULL,
    FOREIGN KEY (created_by)  REFERENCES users(id)
);

-- ── Task History ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS task_history (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    task_id     BIGINT,
    title       VARCHAR(255),
    description VARCHAR(255),
    status      ENUM('TODO','IN_PROGRESS','IN_REVIEW','DONE','CANCELLED'),
    priority    ENUM('LOW','MEDIUM','HIGH','CRITICAL'),
    change_type VARCHAR(255),
    changed_by  VARCHAR(255),
    changed_at  DATETIME(6),
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- ── Notifications ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id        BIGINT NOT NULL,
    title          VARCHAR(200) NOT NULL,
    message        TEXT NOT NULL,
    type           ENUM('PROJECT_ASSIGNED','TASK_ASSIGNED','TASK_UPDATED','PROJECT_UPDATED','USER_CREATED','GENERAL') DEFAULT 'GENERAL',
    is_read        BOOLEAN DEFAULT FALSE,
    reference_id   BIGINT,
    reference_type VARCHAR(50),
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ── Audit Logs ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    action            VARCHAR(100) NOT NULL,
    entity_type       VARCHAR(50)  NOT NULL,
    entity_id         BIGINT,
    entity_name       VARCHAR(200),
    performed_by      BIGINT,
    performed_by_name VARCHAR(100),
    old_value         JSON,
    new_value         JSON,
    ip_address        VARCHAR(50),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (performed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ── Refresh Tokens ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    token       VARCHAR(512) UNIQUE NOT NULL,
    user_id     BIGINT NOT NULL,
    expiry_date TIMESTAMP NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ── Indexes ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tasks_project    ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned   ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status     ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_task_history     ON task_history(task_id);
CREATE INDEX IF NOT EXISTS idx_notif_user       ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_read       ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_audit_entity     ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_performer  ON audit_logs(performed_by);
CREATE INDEX IF NOT EXISTS idx_audit_created    ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_pm_project       ON project_members(project_id);
CREATE INDEX idx_pm_user          ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_manager ON projects(manager_id);
CREATE INDEX IF NOT EXISTS idx_projects_status  ON projects(status);
