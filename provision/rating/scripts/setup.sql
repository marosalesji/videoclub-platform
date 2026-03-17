CREATE TABLE IF NOT EXISTS movies (
    movie_id INTEGER PRIMARY KEY,
    title    TEXT NOT NULL,
    genres   TEXT
);

CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    name    VARCHAR(100) NOT NULL,
    email   VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS ratings (
    id         SERIAL PRIMARY KEY,
    movie_id   INTEGER NOT NULL REFERENCES movies(movie_id),
    user_id    INTEGER NOT NULL REFERENCES users(user_id),
    rating     INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review     VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO users (name, email) VALUES
    ('Ana García',    'ana@videoclub.com'),
    ('Luis Martínez', 'luis@videoclub.com'),
    ('María López',   'maria@videoclub.com'),
    ('Carlos Ruiz',   'carlos@videoclub.com'),
    ('Sofia Torres',  'sofia@videoclub.com')
ON CONFLICT DO NOTHING;
