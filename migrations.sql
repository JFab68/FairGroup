-- Run this in PostgreSQL: psql -d fairgroup -f migrations.sql

CREATE TABLE members (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    password_hash VARCHAR(255),
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'chair', 'vice_chair', 'member')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_members_email ON members(email);

CREATE TABLE subcommittees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    chair_id INTEGER REFERENCES members(id),
    vice_chair_id INTEGER REFERENCES members(id),
    meeting_schedule TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE member_subcommittees (
    member_id INTEGER REFERENCES members(id) ON DELETE CASCADE,
    subcommittee_id INTEGER REFERENCES subcommittees(id) ON DELETE CASCADE,
    PRIMARY KEY (member_id, subcommittee_id)
);

CREATE TABLE resources (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    url VARCHAR(500) NOT NULL,
    category VARCHAR(100),
    scope VARCHAR(20) DEFAULT 'global' CHECK (scope IN ('global', 'subcommittee')),
    subcommittee_id INTEGER REFERENCES subcommittees(id) ON DELETE CASCADE,
    created_by INTEGER REFERENCES members(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_resources_scope ON resources(scope, subcommittee_id);

CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP,
    location VARCHAR(255),
    associated_subcommittee_id INTEGER REFERENCES subcommittees(id) ON DELETE SET NULL,
    created_by INTEGER REFERENCES members(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_events_datetime ON events(start_datetime);

CREATE TABLE attendance (
    id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    member_id INTEGER REFERENCES members(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Present', 'Absent', 'Conflict')),
    notes TEXT,
    recorded_by INTEGER REFERENCES members(id),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(event_id, member_id)
);
CREATE INDEX idx_attendance_event ON attendance(event_id);
CREATE INDEX idx_attendance_member ON attendance(member_id);

CREATE TABLE public_contacts (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    county_or_city VARCHAR(100),
    system_impact VARCHAR(20) CHECK (system_impact IN ('Yes', 'No', 'Prefer not to say')),
    involvement_interest TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Session table for connect-pg-simple
CREATE TABLE session (
    sid VARCHAR(255) PRIMARY KEY,
    sess JSON NOT NULL,
    expire TIMESTAMP NOT NULL
);
CREATE INDEX idx_session_expire ON session(expire);