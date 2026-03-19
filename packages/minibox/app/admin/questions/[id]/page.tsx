import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { query } from '@/lib/db'
import { isAdmin } from '@/lib/auth'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Paperclip, ArrowLeft } from 'lucide-react'
import { AnswerForm } from './answer-form'

interface Question {
  id: number
  question_text: string
  question_attachment_url: string | null
  created_at: string
}

async function getQuestion(id: string): Promise<Question | null> {
  try {
    const result = await query(
      'SELECT * FROM questions WHERE id = $1 AND is_answered = FALSE',
      [id]
    )
    return result.rows[0] ?? null
  } catch (error) {
    console.error('Failed to fetch question:', error)
    return null
  }
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export default async function AnswerQuestionPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  if (!(await isAdmin())) {
    redirect('/admin/login')
  }

  const { id } = await params
  const question = await getQuestion(id)

  if (!question) {
    notFound()
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-lg mx-auto px-4 py-12">
        <Link
          href="/admin"
          className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-900 mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          返回
        </Link>

        {/* Question */}
        <Card className="mb-4">
          <CardHeader>
            <CardTitle className="text-base">问题详情</CardTitle>
          </CardHeader>
          <CardContent>
            <Badge variant="secondary" className="mb-2">提问</Badge>
            <p className="text-gray-800 whitespace-pre-wrap">{question.question_text}</p>
            {question.question_attachment_url && (
              <a
                href={question.question_attachment_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 mt-2 text-sm text-blue-600 hover:underline"
              >
                <Paperclip className="w-3.5 h-3.5" />
                查看附件
              </a>
            )}
            <p className="text-xs text-gray-400 mt-3">{formatDate(question.created_at)}</p>
          </CardContent>
        </Card>

        {/* Answer Form */}
        <AnswerForm questionId={question.id} />
      </div>
    </div>
  )
}
