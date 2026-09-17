// AI 意图识别 ViewModel - 处理日记内容的智能分析
// 使用 LongCat 进行情绪分析、关键词提取、鼓励语生成
import { EmotionAnalyzer, EmotionAnalysisResult } from '../../common/utils/EmotionAnalyzer'
import { MemoryViewModel } from './MemoryViewModel'
import { LongCatService } from '../../common/services/LongCatService'

// 意图识别结果
export interface IntentResult {
  emotion: EmotionAnalysisResult | null
  keywords: string[]
  encouragement?: string
}

// 日记分析结果 - 供 UI 展示
export interface DiaryAnalysisResult {
  keywords: string[]
  emotion: EmotionAnalysisResult | null
  encouragement: string
}

export class IntentViewModel {
  private emotionAnalyzer: EmotionAnalyzer
  private memoryViewModel: MemoryViewModel
  private longCatService: LongCatService
  private lastAnalysisAt: number = 0
  private readonly minAnalysisInterval: number = 10000
  private processedDiaryIds: Set<string> = new Set()

  // API 频率控制
  private lastAPICallTime: number = 0
  private readonly API_CALL_INTERVAL: number = 3000
  private apiCallCount: number = 0
  private readonly MAX_API_CALLS_PER_MINUTE: number = 15
  private apiCallTimestamps: number[] = []

  private static instance: IntentViewModel | null = null

  static getInstance(): IntentViewModel {
    if (!IntentViewModel.instance) {
      IntentViewModel.instance = new IntentViewModel()
    }
    return IntentViewModel.instance
  }

  constructor() {
    this.emotionAnalyzer = EmotionAnalyzer.getInstance()
    this.memoryViewModel = new MemoryViewModel()
    this.longCatService = LongCatService.getInstance()
  }

  private canCallAPI(): boolean {
    const now = Date.now()
    if (now - this.lastAPICallTime < this.API_CALL_INTERVAL) {
      return false
    }
    this.apiCallTimestamps = this.apiCallTimestamps.filter(t => now - t < 60000)
    if (this.apiCallTimestamps.length >= this.MAX_API_CALLS_PER_MINUTE) {
      return false
    }
    return true
  }

  private recordAPICall(): void {
    const now = Date.now()
    this.lastAPICallTime = now
    this.apiCallTimestamps.push(now)
    this.apiCallCount++
  }

  /** 本地备用分析（不调用 API） */
  private async analyzeContentLocally(content: string): Promise<IntentResult> {
    const result: IntentResult = {
      emotion: null,
      keywords: [],
      encouragement: '继续加油！每一天的记录都是成长的见证 💪'
    }

    // 关键词提取
    const extracted = this.memoryViewModel.extractKeywords(content)
    result.keywords = extracted.map(k => k.word)

    // 情绪分析
    result.emotion = await this.emotionAnalyzer.analyze(content)

    // 根据情绪生成鼓励语
    if (result.emotion && result.emotion.emotionKey === 'happy') {
      result.encouragement = '看到你今天心情不错，继续保持这份好心情！😊'
    } else {
      result.encouragement = '每一天的记录都很珍贵，继续加油！💪'
    }

    return result
  }

  /** 使用 LongCat 分析日记内容 */
  async analyzeWithAI(content: string): Promise<IntentResult> {
    if (!this.canCallAPI()) {
      return await this.analyzeContentLocally(content)
    }

    try {
      this.recordAPICall()
      const aiResult = await this.longCatService.analyzeIntent(content)

      const result: IntentResult = {
        emotion: aiResult.extracted?.emotion ? {
          emotionKey: aiResult.extracted.emotion,
          emotionLabel: aiResult.extracted.emotion,
          emotionEmoji: this.getEmojiForEmotion(aiResult.extracted.emotion),
          weatherLabel: '',
          weatherIcon: '',
          colorHex: '',
          confidence: 0.8
        } : null,
        keywords: aiResult.extracted?.keywords ?? [],
        encouragement: aiResult.encouragement || '继续加油！每一天都在进步 💪'
      }

      return result
    } catch (err) {
      console.error('[IntentViewModel] AI分析失败，使用本地备用方案:', err)
      return await this.analyzeContentLocally(content)
    }
  }

  private getEmojiForEmotion(emotion: string): string {
    const emojiMap: Record<string, string> = {
      '开心': '😊', '高兴': '😊', '快乐': '😊',
      '平静': '😌', '一般': '😐',
      '焦虑': '😟', '紧张': '😰',
      '难过': '😢', '伤心': '😢',
      '愤怒': '😡', '生气': '😡',
      '兴奋': '🤩', '激动': '🤩'
    }
    return emojiMap[emotion] ?? '😐'
  }

  /** 分析日记内容（本地备用） */
  async analyzeContent(content: string): Promise<IntentResult> {
    if (!content || content.trim().length === 0) {
      return { emotion: null, keywords: [], encouragement: '' }
    }

    const result: IntentResult = {
      emotion: null,
      keywords: [],
      encouragement: ''
    }

    // 情绪分析
    try {
      result.emotion = await this.emotionAnalyzer.analyze(content)
    } catch (err) {
      console.error('[IntentViewModel] 情绪分析失败:', err)
    }

    // 关键词提取
    const extracted = this.memoryViewModel.extractKeywords(content)
    result.keywords = extracted.map(k => k.word)

    return result
  }

  /** 分析日记内容，返回情绪、关键词、鼓励语 */
  async analyzeDiaryForConfirmation(content: string, diaryId: string): Promise<DiaryAnalysisResult> {
    const result: DiaryAnalysisResult = {
      keywords: [],
      emotion: null,
      encouragement: ''
    }

    if (!content || content.length < 5) {
      return result
    }

    if (this.processedDiaryIds.has(diaryId)) {
      return result
    }

    // 节流
    const now = Date.now()
    if (now - this.lastAnalysisAt < this.minAnalysisInterval) {
      result.encouragement = this.getDefaultEncouragement('neutral')
      this.processedDiaryIds.add(diaryId)
      return result
    }
    this.lastAnalysisAt = now

    try {
      const intent = await this.analyzeWithAI(content)
      result.keywords = intent.keywords
      result.emotion = intent.emotion
      result.encouragement = await this.generateEncouragement(content, intent.emotion)
      this.processedDiaryIds.add(diaryId)
    } catch (err) {
      console.error('[IntentViewModel] 分析日记失败:', err)
      result.encouragement = this.getDefaultEncouragement('neutral')
      this.processedDiaryIds.add(diaryId)
    }

    return result
  }

  /** 生成 AI 温馨鼓励语 */
  async generateEncouragement(content: string, emotion: EmotionAnalysisResult | null): Promise<string> {
    try {
      const emotionText = emotion?.emotionLabel ?? '平静'
      const prompt = `用户刚写完一篇日记，情绪状态是"${emotionText}"。
日记内容摘要：${content.slice(0, 100)}...

请生成一句温馨、鼓励的回复（20-40字），要求：
1. 如果用户焦虑/疲惫，给予安慰和理解
2. 如果用户开心/兴奋，表达祝贺和认可
3. 如果用户提到学习目标，给予鼓励
4. 语气温暖友好，像朋友一样

只返回鼓励语本身，不要加引号或其他格式。`

      const response = await this.longCatService.chatFast(prompt)
      return response || '每一次记录都是成长的足迹，继续加油！💪'
    } catch (err) {
      console.error('[IntentViewModel] 生成鼓励语失败:', err)
      return this.getDefaultEncouragement(emotion?.emotionKey ?? 'neutral')
    }
  }

  private getDefaultEncouragement(emotion: string): string {
    const encouragements: Record<string, string> = {
      'happy': '今天的好心情要继续保持哦！🌟',
      'excited': '太棒了！每一份努力都值得被记录！🎉',
      'calm': '平静的心态是最好的状态，继续加油！😊',
      'anxious': '深呼吸，一切都会好起来的。相信自己！💪',
      'tired': '辛苦了，适当休息也是进步的一部分。🌙',
      'sad': '低落的时候记得，明天又是新的开始。🌈',
      'neutral': '每一次记录都是成长的足迹，继续加油！✨'
    }
    return encouragements[emotion] ?? encouragements['neutral']
  }

  /** 自动保存关键词到记忆库 */
  async autoSaveKeywords(content: string): Promise<number> {
    const keywords = this.memoryViewModel.extractKeywords(content)
    const allKeywords: string[] = keywords.map(k => k.word)
    if (allKeywords.length > 0) {
      return await this.memoryViewModel.saveKeywords(allKeywords)
    }
    return 0
  }

  resetProcessedDiaries(): void {
    this.processedDiaryIds.clear()
  }
}
