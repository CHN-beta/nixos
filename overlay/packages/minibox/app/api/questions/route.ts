import { NextResponse } from 'next/server'
import { query } from '@/lib/db'
import { saveFile, MAX_FILE_SIZE } from '@/lib/upload'
import { sendTelegramMessage } from '@/lib/telegram'

export async function GET() {
  try {
    const result = await query(
      'SELECT * FROM questions WHERE is_answered = TRUE ORDER BY answered_at DESC'
    )
    return NextResponse.json(result.rows)
  } catch (error) {
    console.error('GET /api/questions error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData()
    const questionText = formData.get('question_text') as string | null
    const attachment = formData.get('attachment') as File | null

    if (!questionText || questionText.trim() === '') {
      return NextResponse.json({ error: 'Question text is required' }, { status: 400 })
    }

    let attachmentUrl: string | null = null
    if (attachment && attachment.size > 0) {
      if (attachment.size > MAX_FILE_SIZE) {
        return NextResponse.json({ error: 'File size exceeds 10MB limit' }, { status: 400 })
      }
      attachmentUrl = await saveFile(attachment)
    }

    await query(
      'INSERT INTO questions (question_text, question_attachment_url) VALUES ($1, $2)',
      [questionText.trim(), attachmentUrl]
    )

    // Send Telegram notification
    await sendTelegramMessage(`收到新的提问：\n\n${questionText.trim()}`)

    return NextResponse.json({ success: true }, { status: 201 })
  } catch (error) {
    console.error('POST /api/questions error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
