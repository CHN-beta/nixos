import { getIronSession, SessionOptions } from 'iron-session'
import { cookies } from 'next/headers'

export interface SessionData {
  isAdmin?: boolean
}

export function getSessionOptions(): SessionOptions {
  const secret = process.env.SESSION_SECRET
  if (!secret) {
    throw new Error('SESSION_SECRET environment variable is not set')
  }
  return {
    cookieName: 'minibox-session',
    password: secret,
    cookieOptions: {
      secure: process.env.NODE_ENV === 'production',
    },
  }
}

export async function getSession() {
  const cookieStore = await cookies()
  return getIronSession<SessionData>(cookieStore, getSessionOptions())
}

export async function isAdmin(): Promise<boolean> {
  const session = await getSession()
  return session.isAdmin === true
}
