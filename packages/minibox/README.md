# 问答箱 (MiniBox)

A single-user Q&A Box web application built with Next.js, Tailwind CSS, shadcn/ui components, and PostgreSQL.

## Features

- **Visitor**: Browse answered Q&A pairs, submit anonymous questions (with optional file attachments up to 10MB)
- **Admin**: Login with a password, view unanswered questions, answer them (with optional attachments), delete questions

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Styling**: Tailwind CSS + custom shadcn/ui components
- **Database**: PostgreSQL
- **File Storage**: Local filesystem (`uploads/` directory)
- **Auth**: iron-session (cookie-based sessions)

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Set up PostgreSQL database

Create a database and run the schema:

```bash
psql -U postgres -c "CREATE DATABASE minibox;"
```

The `questions` table is created automatically on first startup.

### 3. Configure environment variables

Copy `.env.example` to `.env.local` and fill in the values:

```bash
cp .env.example .env.local
```

Edit `.env.local`:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/minibox
ADMIN_PASSWORD=your-secure-password
SESSION_SECRET=your-random-secret-at-least-32-chars
PORT=3000
```

### 4. Run the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) (or the port set via `PORT`).

### 5. Build for production

```bash
npm run build
npm start
```

## File Upload Storage

Uploaded files are stored in the `uploads/` directory at the project root. Ensure this directory is writable by the server process. The directory is created automatically on first upload.

**Max file size**: 10MB per file. All file formats are accepted.

## Admin Access

Navigate to `/admin/login` to access the admin panel. Use the password set in `ADMIN_PASSWORD`.

## API Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/questions` | Get all answered questions (public) |
| POST | `/api/questions` | Submit a new question (public) |
| POST | `/api/questions/[id]/answer` | Answer a question (admin) |
| GET | `/api/admin/questions` | Get all unanswered questions (admin) |
| DELETE | `/api/admin/questions/[id]` | Delete a question (admin) |
| POST | `/api/auth/login` | Admin login |
| POST | `/api/auth/logout` | Admin logout |
| GET | `/api/uploads/[filename]` | Serve uploaded files |

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS questions (
  id SERIAL PRIMARY KEY,
  question_text TEXT NOT NULL,
  question_attachment_url VARCHAR(500),
  answer_text TEXT,
  answer_attachment_url VARCHAR(500),
  is_answered BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  answered_at TIMESTAMP WITH TIME ZONE
);
```

---

_Bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app)._
