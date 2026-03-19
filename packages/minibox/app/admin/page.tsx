import Link from 'next/link'
import { redirect } from 'next/navigation'
import { query } from '@/lib/db'
import { isAdmin } from '@/lib/auth'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Paperclip, MessageSquare } from 'lucide-react'
import { LogoutButton } from './logout-button'

export const revalidate = 0

interface Question {
  id: number
  question_text: string
  question_attachment_url: string | null
  created_at: string
}

async function getUnansweredQuestions(): Promise<Question[]> {
  try {
    const result = await query(
      'SELECT * FROM questions WHERE is_answered = FALSE ORDER BY created_at DESC'
    )
    return result.rows
  } catch (error) {
    console.error('Failed to fetch unanswered questions:', error)
    return []
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

export default async function AdminPage() {
  if (!(await isAdmin())) {
    redirect('/admin/login')
  }

  const questions = await getUnansweredQuestions()

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-12">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">管理后台</h1>
            <p className="text-gray-500 text-sm mt-1">待回答问题 ({questions.length})</p>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/" className="text-sm text-gray-500 hover:text-gray-900">
              查看前台
            </Link>
            <LogoutButton />
          </div>
        </div>

        {/* Questions */}
        {questions.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <MessageSquare className="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p>暂无待回答的问题</p>
          </div>
        ) : (
          <div className="space-y-4">
            {questions.map((q) => (
              <Card key={q.id}>
                <CardContent className="pt-6">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 min-w-0">
                      <Badge variant="secondary" className="mb-2">待回答</Badge>
                      <p className="text-gray-800 whitespace-pre-wrap break-words">{q.question_text}</p>
                      {q.question_attachment_url && (
                        <a
                          href={q.question_attachment_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 mt-2 text-sm text-blue-600 hover:underline"
                        >
                          <Paperclip className="w-3.5 h-3.5" />
                          查看附件
                        </a>
                      )}
                      <p className="text-xs text-gray-400 mt-3">{formatDate(q.created_at)}</p>
                    </div>
                    <Link
                      href={`/admin/questions/${q.id}`}
                      className="shrink-0 inline-flex items-center justify-center h-8 px-3 text-sm font-medium rounded-md bg-gray-900 text-white hover:bg-gray-700 transition-colors"
                    >
                      回答
                    </Link>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
