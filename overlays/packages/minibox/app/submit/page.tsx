'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { ArrowLeft, CheckCircle, Paperclip } from 'lucide-react'

export default function SubmitPage() {
  const [questionText, setQuestionText] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!questionText.trim()) {
      setError('请输入问题内容')
      return
    }

    if (file && file.size > 10 * 1024 * 1024) {
      setError('文件大小不能超过 10MB')
      return
    }

    setLoading(true)
    try {
      const formData = new FormData()
      formData.append('question_text', questionText.trim())
      if (file) formData.append('attachment', file)

      const res = await fetch('/api/questions', { method: 'POST', body: formData })
      const data = await res.json()

      if (!res.ok) {
        setError(data.error || '提交失败，请重试')
      } else {
        setSuccess(true)
      }
    } catch {
      setError('提交失败，请检查网络连接')
    } finally {
      setLoading(false)
    }
  }

  if (success) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <Card className="w-full max-w-md text-center">
          <CardContent className="pt-8 pb-8">
            <CheckCircle className="w-14 h-14 text-green-500 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 mb-2">提交成功！</h2>
            <p className="text-gray-500 mb-6">你的问题已提交，等待回答。</p>
            <div className="flex flex-col gap-2">
              <Button onClick={() => { setSuccess(false); setQuestionText(''); setFile(null) }} variant="outline">
                继续提问
              </Button>
              <Link href="/">
                <Button className="w-full">查看已回答问题</Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-lg mx-auto px-4 py-12">
        <Link href="/" className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-900 mb-6">
          <ArrowLeft className="w-4 h-4" />
          返回
        </Link>

        <Card>
          <CardHeader>
            <CardTitle>提交问题</CardTitle>
            <CardDescription>匿名提问，主人会尽快回答你的问题。</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="question">问题内容 *</Label>
                <Textarea
                  id="question"
                  placeholder="请输入你想问的问题..."
                  value={questionText}
                  onChange={(e) => setQuestionText(e.target.value)}
                  rows={5}
                  required
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
                {loading ? '提交中...' : '提交问题'}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
