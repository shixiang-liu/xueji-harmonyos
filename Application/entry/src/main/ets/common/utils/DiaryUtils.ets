// 日记模块辅助函数
import { speechRecognizer } from '@kit.CoreSpeechKit'

// 格式化时长 (秒 -> mm:ss)
export function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

// 格式化日期 (时间戳 -> yyyy-MM-dd)
export function formatDate(timestamp: number): string {
  const date = new Date(timestamp)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

// 格式化相对时间
export function formatTimeAgo(timestamp: number): string {
  const now = Date.now()
  const diff = now - timestamp
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)

  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`
  if (days < 7) return `${days}天前`
  return new Date(timestamp).toLocaleDateString()
}

// 获取文件显示名称
export function getFileDisplayName(path: string): string {
  if (!path) return '未知文件'
  const normalized = path.split('?')[0]
  const segments = normalized.split('/')
  const last = segments[segments.length - 1]
  return last || normalized
}

// 选择最佳识别结果
export function pickBestRecognizedText(result: speechRecognizer.SpeechRecognitionResult): string {
  return result.result || ''
}

// 生成唯一ID
export function generateId(prefix: string = 'id'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
}

// 限制文本长度
export function truncateText(text: string, maxLength: number): string {
  if (!text || text.length <= maxLength) return text
  return text.substring(0, maxLength - 3) + '...'
}

// 计算字数（支持中文）
export function countWords(text: string): number {
  if (!text) return 0
  // 中文按字符计数，英文按空格分词
  const chineseChars = (text.match(/[\u4e00-\u9fa5]/g) || []).length
  const englishWords = (text.match(/[a-zA-Z]+/g) || []).length
  return chineseChars + englishWords
}

// 验证URL格式
export function isValidUrl(url: string): boolean {
  if (!url) return false
  try {
    const pattern = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/i
    return pattern.test(url)
  } catch {
    return false
  }
}

// 确保URL有协议前缀
export function ensureUrlProtocol(url: string): string {
  if (!url) return ''
  const trimmed = url.trim()
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return 'https://' + trimmed
  }
  return trimmed
}
