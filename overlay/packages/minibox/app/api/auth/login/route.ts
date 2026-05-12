import { NextResponse } from 'next/server'
import { getSession } from '@/lib/auth'

export async function POST(request: Request) {
  try {
    const { password } = await request.json()

    if (!password || password !== process.env.ADMIN_PASSWORD) {
      return NextResponse.json({ error: 'Invalid password' }, { status: 401 })
    }

    const session = await getSession()
    session.isAdmin = true
    await session.save()

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('POST /api/auth/login error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
