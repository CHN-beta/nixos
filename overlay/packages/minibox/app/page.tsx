import Link from 'next/link'
import { query } from '@/lib/db'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { MessageCircle, Paperclip } from 'lucide-react'

export const revalidate = 0

interface Question {
  id: number
  question_text: string
  question_attachment_url: string | null
  answer_text: string
  answer_attachment_url: string | null
  answered_at: string
}

async function getAnsweredQuestions(): Promise<Question[]> {
  try {
    const result = await query(
      'SELECT * FROM questions WHERE is_answered = TRUE ORDER BY answered_at DESC'
    )
    return result.rows
  } catch (error) {
    console.error('Failed to fetch questions:', error)
    return []
  }
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

export default async function HomePage() {
  const questions = await getAnsweredQuestions()

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-12">
        {/* Header */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-14 h-14 bg-gray-900 rounded-full mb-4">
            <MessageCircle className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">问答箱</h1>
          <p className="text-gray-500 mb-6">匿名提问，诚实作答</p>
          <Link href="/submit">
            <Button size="lg" className="px-8">提交问题</Button>
          </Link>
        </div>

        {/* Q&A List */}
        {questions.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <MessageCircle className="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p>暂无已回答的问题</p>
          </div>
        ) : (
          <div className="space-y-4">
            {questions.map((q) => (
              <Card key={q.id}>
                <CardContent className="pt-6">
                  {/* Question */}
                  <div className="mb-4">
                    <Badge variant="secondary" className="mb-2">提问</Badge>
                    <p className="text-gray-800 whitespace-pre-wrap">{q.question_text}</p>
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
                  </div>

                  {/* Divider */}
                  <div className="border-t border-gray-100 mb-4" />

                  {/* Answer */}
                  <div>
                    <Badge className="mb-2">回答</Badge>
                    <p className="text-gray-800 whitespace-pre-wrap">{q.answer_text}</p>
                    {q.answer_attachment_url && (
                      <a
                        href={q.answer_attachment_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 mt-2 text-sm text-blue-600 hover:underline"
                      >
                        <Paperclip className="w-3.5 h-3.5" />
                        查看附件
                      </a>
                    )}
                    <p className="text-xs text-gray-400 mt-3">{formatDate(q.answered_at)}</p>
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
