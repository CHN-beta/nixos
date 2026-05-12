'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Paperclip } from 'lucide-react'

interface AnswerFormProps {
  questionId: number
}

export function AnswerForm({ questionId }: AnswerFormProps) {
  const router = useRouter()
  const [answerText, setAnswerText] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!answerText.trim()) {
      setError('请输入回答内容')
      return
    }

    if (file && file.size > 10 * 1024 * 1024) {
      setError('文件大小不能超过 10MB')
      return
    }

    setLoading(true)
    try {
      const formData = new FormData()
      formData.append('answer_text', answerText.trim())
      if (file) formData.append('attachment', file)

      const res = await fetch(`/api/questions/${questionId}/answer`, {
        method: 'POST',
        body: formData,
      })
      const data = await res.json()

      if (!res.ok) {
        setError(data.error || '提交失败，请重试')
      } else {
        router.push('/admin')
        router.refresh()
      }
    } catch {
      setError('提交失败，请检查网络连接')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">回答问题</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="answer">回答内容 *</Label>
            <Textarea
              id="answer"
              placeholder="请输入你的回答..."
              value={answerText}
              onChange={(e) => setAnswerText(e.target.value)}
              rows={6}
              required
              autoFocus
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="attachment" className="flex items-center gap-1.5">
              <Paperclip className="w-3.5 h-3.5" />
              附件（可选）
            </Label>
            <input
              id="attachment"
              type="file"
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              className="block w-full text-sm text-gray-500 file:mr-4 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-gray-100 file:text-gray-700 hover:file:bg-gray-200"
            />
            <p className="text-xs text-gray-400">最大文件大小：10MB</p>
          </div>

          {error && (
            <p className="text-sm text-red-500 bg-red-50 rounded-md px-3 py-2">{error}</p>
          )}

          <Button type="submit" disabled={loading} className="w-full">
            {loading ? '提交中...' : '提交回答'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
