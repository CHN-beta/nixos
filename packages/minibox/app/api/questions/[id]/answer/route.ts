import { NextResponse } from 'next/server'
import { query } from '@/lib/db'
import { isAdmin } from '@/lib/auth'
import { saveFile, MAX_FILE_SIZE } from '@/lib/upload'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    if (!(await isAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { id } = await params
    const formData = await request.formData()
    const answerText = formData.get('answer_text') as string | null
    const attachment = formData.get('attachment') as File | null

    if (!answerText || answerText.trim() === '') {
      return NextResponse.json({ error: 'Answer text is required' }, { status: 400 })
    }

    let attachmentUrl: string | null = null
    if (attachment && attachment.size > 0) {
      if (attachment.size > MAX_FILE_SIZE) {
        return NextResponse.json({ error: 'File size exceeds 10MB limit' }, { status: 400 })
      }
      attachmentUrl = await saveFile(attachment)
    }

    const result = await query(
      `UPDATE questions
       SET answer_text = $1, answer_attachment_url = $2, is_answered = TRUE, answered_at = NOW()
       WHERE id = $3`,
      [answerText.trim(), attachmentUrl, id]
    )

    if (result.rowCount === 0) {
      return NextResponse.json({ error: 'Question not found' }, { status: 404 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('POST /api/questions/[id]/answer error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
