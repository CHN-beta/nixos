import { NextResponse } from 'next/server'
import { getSession } from '@/lib/auth'

export async function POST() {
  try {
    const session = await getSession()
    session.destroy()
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('POST /api/auth/logout error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
