// ============================================================================
// AI 服务 - LongCat
// ============================================================================
// 功能：意图识别、情绪分析、白噪音推荐、复盘对话
// ============================================================================
import http from '@ohos.net.http'
import { NetworkService } from './NetworkService'

// API 响应类型定义

interface LongCatChoice {
  index: number
  message: LongCatMessage
  finish_reason: string
}

interface LongCatMessage {
  role: string
  content: string
}

// 聊天消息类型 - 用于构建请求消息数组
interface LongCatChatMessage {
  role: string
  content: string
}

interface LongCatUsage {
  prompt_tokens: number
  completion_tokens: number
  total_tokens: number
}

interface LongCatResponse {
  id: string
  created: number
  model: string
  choices: LongCatChoice[]
  usage: LongCatUsage
}

interface LongCatThinkingConfig {
  type: string
}

// JSON 格式强制输出配置
interface LongCatResponseFormat {
  type: string
}

// 阻碍分析结果接口
interface ObstacleAnalysisResult {
  obstacles: string[]
  report: string
}

// API 请求体类型
interface LongCatRequestBody {
  model: string
  messages: LongCatChatMessage[]
  max_tokens: number
  temperature: number
  thinking?: LongCatThinkingConfig
  response_format?: LongCatResponseFormat
}

// 业务层返回类型

export interface IntentResult {
  type: 'goal' | 'todo' | 'emotion' | 'question' | 'chat'
  content: string
  confidence: number
  extracted?: ExtractedInfo
  encouragement?: string  // AI 温馨鼓励语
}

export interface ExtractedInfo {
  goals?: string[]
  todos?: string[]
  keywords?: string[]
  emotion?: string
  emotionScore?: number // 1-5, 越高心情越好
}

export interface NoiseRecommendation {
  type: string
  reason: string
}

// 情绪分析结果
export interface EmotionAnalysisResult {
  emotion: string
  score: number
  emoji: string
}

// 复盘卡片结构化结果
export interface ReflectionSummaryResult {
  title: string
  takeaways: string[]
  questions: string[]
  plan: string[]
}

// 默认返回结构（兜底用）
const DEFAULT_INTENT: IntentResult = {
  type: 'chat',
  content: '',
  confidence: 0,
  extracted: {
    goals: [],
    todos: [],
    keywords: [],
    emotion: '平静',
    emotionScore: 3
  }
}

const DEFAULT_EMOTION: EmotionAnalysisResult = {
  emotion: '平静',
  score: 3,
  emoji: '😐'
}

const DEFAULT_NOISE: NoiseRecommendation = {
  type: 'rain',
  reason: '舒缓的雨声帮助专注'
}

export class LongCatService {
  private static instance: LongCatService | null = null
  // 网络服务（用于检测联网状态）
  private networkService: NetworkService = NetworkService.getInstance()
  // LongCat 开放平台 — OpenAI 格式
  private readonly longCatApiKey: string = '' // 从本地配置注入，勿提交真实 Key
  private readonly longCatBaseUrl: string = 'https://api.longcat.chat/openai/v1/chat/completions'
  private readonly longCatChatModel: string = 'LongCat-Flash-Chat'  // 主对话，500K tokens/天
  private readonly longCatLiteModel: string = 'LongCat-Flash-Lite'  // 轻量任务（标签建议），50M tokens/天

  // 请求频率限制：记录上次请求时间
  private lastRequestTime: number = 0
  private readonly minRequestInterval: number = 300 // 300ms，避免极端突发

  private constructor() {
  }

  static getInstance(): LongCatService {
    if (!LongCatService.instance) {
      LongCatService.instance = new LongCatService()
    }
    return LongCatService.instance
  }

  // 通用聊天 - 其他方法的基础
  async chat(prompt: string, systemPrompt?: string, useJsonFormat: boolean = false): Promise<string> {
    return this.chatWithProvider(prompt, systemPrompt, useJsonFormat, false)
  }

  // 轻量任务：标签建议、情绪打分等高频低难度场景，用 LongCat-Lite（50M/天 免费额度）
  async chatLite(prompt: string, systemPrompt?: string, useJsonFormat: boolean = false): Promise<string> {
    return this.chatWithProvider(prompt, systemPrompt, useJsonFormat, true)
  }

  /** 仅 LongCat — 失败立即返回空串，适合对速度敏感的场景 */
  async chatFast(prompt: string, systemPrompt?: string, useJsonFormat: boolean = false): Promise<string> {
    const messages: LongCatChatMessage[] = []
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt })
    }
    messages.push({ role: 'user', content: prompt })
    try {
      const response = await this.callLongCatAPI(messages, useJsonFormat, false)
      return response.choices[0]?.message?.content ?? ''
    } catch (err) {
      console.warn('[LongCatService] chatFast 失败:', err)
      return ''
    }
  }

  /**
   * 主调用入口：LongCat
   * @param useLite true 用 LongCat-Flash-Lite（轻量），false 用 LongCat-Flash-Chat（主力）
   */
  private async chatWithProvider(
    prompt: string,
    systemPrompt: string | undefined,
    useJsonFormat: boolean,
    useLite: boolean
  ): Promise<string> {
    const messages: LongCatChatMessage[] = []
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt })
    }
    messages.push({ role: 'user', content: prompt })

    try {
      const response = await this.callLongCatAPI(messages, useJsonFormat, useLite)
      return response.choices[0]?.message?.content ?? ''
    } catch (err) {
      console.error('[LongCatService] LongCat 调用失败:', err)
      return ''
    }
  }

  // 从日记中提取目标、待办、情绪等结构化信息
  async analyzeIntent(content: string): Promise<IntentResult> {
    const systemPrompt = `你是一个智能学习助手，负责分析用户的日记内容。
请从内容中识别：
1. 学习目标（如：我要考过四级、准备期末考试）
2. 待办事项（如：明天要交作业、下周复习）
3. 情绪状态（开心、焦虑、压力大、平静等）
4. 学习阻碍关键词（手机、游戏、熬夜、拖延等）

请严格以 JSON 格式返回，不要输出任何其他文字：
{
  "type": "goal|todo|emotion|chat",
  "goals": ["目标1", "目标2"],
  "todos": ["待办1", "待办2"],
  "keywords": ["关键词1", "关键词2"],
  "emotion": "情绪标签",
  "emotionScore": 3
}
emotionScore: 1=很差 2=不好 3=一般 4=不错 5=很好`

    try {
      // 使用 JSON 格式强制返回结构化数据
      const response = await this.chatFast(content, systemPrompt, true)
      return this.parseIntentResponse(response)
    } catch (err) {
      console.error('[LongCatService] analyzeIntent error:', err)
      // 离线或失败时返回默认结果
      return DEFAULT_INTENT
    }
  }

  // 情绪分析 - 用于学习记录的情绪标签和建议
  async analyzeEmotion(content: string): Promise<EmotionAnalysisResult> {
    const systemPrompt = `分析以下文本的情绪状态，严格返回 JSON 格式，不要输出任何其他文字：
{
  "emotion": "情绪标签（开心/平静/焦虑/难过/愤怒/兴奋）",
  "score": 情绪分数1-5,
  "emoji": "对应的emoji表情"
}`

    try {
      // 使用 JSON 格式强制返回
      const response = await this.chat(content, systemPrompt, true)
      const json = this.extractJSON(response)
      const result: EmotionAnalysisResult = {
        emotion: (json.emotion as string) ?? '平静',
        score: (json.score as number) ?? 3,
        emoji: (json.emoji as string) ?? '😐'
      }
      return result
    } catch (err) {
      console.error('[LongCatService] analyzeEmotion error:', err)
      return DEFAULT_EMOTION
    }
  }

  // 基于情绪推荐白噪音类型，减少用户选择负担
  async recommendNoise(emotion: string, currentActivity?: string): Promise<NoiseRecommendation> {
    const systemPrompt = `你是一个专注力专家。根据用户当前的情绪状态推荐最合适的白噪音类型。
可选类型：rain(雨声)、ocean(海浪)、forest(森林)、library(图书馆)、fire(壁炉)、none(无)

严格返回 JSON 格式，不要输出任何其他文字：
{
  "type": "rain|ocean|forest|library|fire|none",
  "reason": "推荐理由（一句话）"
}`

    const prompt = `用户情绪：${emotion}${currentActivity ? `\n当前活动：${currentActivity}` : ''}`

    try {
      // 使用 JSON 格式强制返回
      const response = await this.chat(prompt, systemPrompt, true)
      const json = this.extractJSON(response)
      const result: NoiseRecommendation = {
        type: (json.type as string) ?? 'rain',
        reason: (json.reason as string) ?? '帮助你更好地专注'
      }
      return result
    } catch (err) {
      console.error('[LongCatService] recommendNoise error:', err)
      return DEFAULT_NOISE
    }
  }

  // 分析日记中的学习阻碍（使用LLM真实分析而非关键词匹配）
  async analyzeObstacles(diaryContents: string[]): Promise<ObstacleAnalysisResult> {
    const emptyResult: ObstacleAnalysisResult = { obstacles: [], report: '暂无日记数据可分析' }
    if (diaryContents.length === 0) {
      return emptyResult
    }

    // 合并日记内容，限制长度避免token过多
    const combinedContent = diaryContents.map((c, i) => `[日记${i + 1}] ${c}`).join('\n').substring(0, 3000)

    const systemPrompt = `你是一个专业的学习行为分析师。请仔细阅读用户近期的日记内容，分析影响学习的真实阻碍因素。

注意事项：
1. 仔细理解语境，识别否定句。如"我没玩手机"说明用户没有玩手机，不应计为阻碍
2. 只提取真正影响学习的因素，不要误判
3. 分析要基于日记的实际内容，不要臆断

严格返回JSON格式：
{
  "obstacles": ["阻碍1", "阻碍2", "阻碍3"],
  "report": "一段50-100字的分析报告，说明主要阻碍因素和改进建议"
}`

    try {
      const response = await this.chat(combinedContent, systemPrompt, true)
      const json = this.extractJSON(response)
      const result: ObstacleAnalysisResult = {
        obstacles: (json.obstacles as string[]) ?? [],
        report: (json.report as string) ?? '分析完成'
      }
      return result
    } catch (err) {
      console.error('[LongCatService] analyzeObstacles error:', err)
      const errorResult: ObstacleAnalysisResult = { obstacles: [], report: '分析失败，请稍后重试' }
      return errorResult
    }
  }

  // 根据阻碍和目标给出针对性建议
  async generateStudyAdvice(obstacles: string[], goals: string[]): Promise<string> {
    const systemPrompt = `你是一个学习教练，帮助学生提高学习效率。
请根据用户的学习阻碍和目标，给出简洁实用的建议。
建议要具体、可执行，不超过100字。`

    const prompt = `我的学习阻碍：${obstacles.join('、')}
我的目标：${goals.join('、')}
请给我一条建议。`

    try {
      return await this.chat(prompt, systemPrompt)
    } catch (err) {
      console.error('[LongCatService] generateStudyAdvice error:', err)
      return '建议：合理规划时间，减少干扰，专注当下任务。'
    }
  }

  /**
   * 通过联网搜索获取目标的真实截止日期
   * @param goalTitle 目标标题，如"考研"、"四级"、"六级"
   * @returns 截止日期时间戳，如果无法确定则返回 null
   */
  async searchGoalDeadline(goalTitle: string): Promise<number | null> {
    const currentYear = new Date().getFullYear()
    const currentMonth = new Date().getMonth() + 1

    const systemPrompt = `你是一个精准的考试日期查询助手。
请根据用户的目标，联网搜索并返回最近一次该考试/目标的具体日期。
当前日期：${currentYear}年${currentMonth}月

要求：
1. 搜索最新的官方公布的考试时间
2. 如果是考研，返回全国硕士研究生招生考试初试日期
3. 如果是四级/六级(CET)，返回最近一次考试日期
4. 如果是高考/中考等，返回对应的考试日期
5. 如果目标没有固定日期，返回 null

严格以 JSON 格式返回，不要输出任何其他文字：
{
  "found": true或false,
  "year": 年份数字,
  "month": 月份数字(1-12),
  "day": 日期数字,
  "examName": "具体考试名称",
  "source": "信息来源说明"
}`

    const prompt = `请帮我查询"${goalTitle}"的最近一次考试/截止日期是什么时候？`

    try {
      // 使用 JSON 格式强制返回结构化数据
      const response = await this.chat(prompt, systemPrompt, true)
      const json = this.extractJSON(response)

      if (json.found === true && json.year && json.month && json.day) {
        const year = json.year as number
        const month = (json.month as number) - 1 // JavaScript 月份从 0 开始
        const day = json.day as number

        const deadline = new Date(year, month, day)
        console.info(`[LongCatService] 搜索到 "${goalTitle}" 截止日期: ${deadline.toLocaleDateString()}，来源: ${json.source}`)

        return deadline.getTime()
      }

      console.info(`[LongCatService] 未找到 "${goalTitle}" 的具体截止日期`)
      return null
    } catch (err) {
      console.error('[LongCatService] searchGoalDeadline error:', err)
      return null
    }
  }

  /**
   * 生成温暖的 AI 鼓励语
   * @param content 日记内容
   * @param emotion 情绪状态
   * @returns 鼓励语
   */
  async generateEncouragement(content: string, emotion: string): Promise<string> {
    const systemPrompt = `你是一个温暖贴心的学习伙伴。
请根据用户的日记内容和情绪状态，给出一句简短温暖的鼓励。
要求：
1. 语气亲切、像朋友一样
2. 针对具体内容给出鼓励
3. 不超过50字
4. 可以适当使用 emoji

直接返回鼓励语，不要任何前缀或解释。`

    const prompt = `用户情绪：${emotion}\n日记内容：${content.substring(0, 200)}`

    try {
      const response = await this.chat(prompt, systemPrompt)
      return response || '今天也要加油哦！💪'
    } catch (err) {
      console.error('[LongCatService] generateEncouragement error:', err)
      return '继续保持，你做得很棒！✨'
    }
  }

  // 一句话总结日记，用于列表预览
  async summarizeDiary(content: string): Promise<string> {
    const systemPrompt = `请用一句话总结这篇日记的核心内容，不超过30字。`

    try {
      return await this.chat(content, systemPrompt)
    } catch (err) {
      console.error('[LongCatService] summarizeDiary error:', err)
      return ''
    }
  }

  // ==================== 复盘对话 ====================

  /**
   * 复盘对话的下一轮：根据已有对话历史，让 AI 生成下一个引导问题
   * @param history user/assistant 交替的对话数组
   * @param lastUnresolved 昨天未解决的困惑（用于第一轮主动追问）
   * @param turnIndex 当前是第几轮（0=开场，4+=收尾）
   * @param daySummaryContext 今天普通学习记录摘要（用于让复盘问题更具体）
   */
  async reflectionTurn(
    history: LongCatChatMessage[],
    lastUnresolved: string[],
    turnIndex: number,
    daySummaryContext: string = ''
  ): Promise<string> {
    const unresolvedHint = lastUnresolved.length > 0
      ? `\n\n用户昨天遗留了这些困惑（如果用户第一句没主动提，请在第 1 轮温和追问其中 1 个）：\n${lastUnresolved.map(q => `- ${q}`).join('\n')}`
      : ''
    const daySummaryHint = daySummaryContext.trim().length > 0
      ? `\n\n今天的学习记录摘要（可用于提问，但不要逐字复述）：\n${daySummaryContext.trim()}`
      : ''

    const stage = turnIndex === 0 ? '开场' : '深入'

    const systemPrompt = `你是一个温暖的学习教练，正在跟用户做睡前复盘对话。
当前阶段：${stage}（这是第 ${turnIndex + 1} 轮）。

对话原则：
- 一次只问 1 个问题，简短自然，不超过 30 字
- 像朋友聊天，不要客套话、不要 bullet list、不要 emoji 过载
- 开场（第 1 轮）：温暖问候 + 抛 1 个开放问题（如「今天最有收获的是什么」）
- 如果今天有学习记录，优先围绕记录里的标题、分类或多媒体证据提 1 个具体问题
- 深入：根据用户回答深挖。可以问"为什么印象深"、"哪里卡住"、"明天打算"
- 当用户说"没有了"、"没了"、"就这些"或回答得很简短，立刻总结 + 道晚安，告诉用户「我帮你整理成今日卡片」
- 不要主动结束对话，除非用户明确表示聊完了${unresolvedHint}${daySummaryHint}

直接返回你要说的话，不要任何前缀或解释，不要带"AI:"。`

    const messages: LongCatChatMessage[] = [{ role: 'system', content: systemPrompt }, ...history]
    try {
      const response = await this.callLongCatAPI(messages, false, false)
      return response.choices[0]?.message?.content?.trim() ?? ''
    } catch (err) {
      console.error('[LongCatService] reflectionTurn 失败:', err)
      return turnIndex === 0
        ? '晚上好。今天学习怎么样？最让你印象深的是什么？'
        : '明白了。还有什么想聊的吗？'
    }
  }

  /**
   * 把整段复盘对话总结成结构化卡片
   */
  async reflectionSummary(history: LongCatChatMessage[], daySummaryContext: string = ''): Promise<ReflectionSummaryResult> {
    const dialogue = history
      .filter(m => m.role === 'user' || m.role === 'assistant')
      .map(m => `${m.role === 'user' ? '我' : 'AI'}: ${m.content}`)
      .join('\n')
    const daySummaryHint = daySummaryContext.trim().length > 0
      ? `\n\n今天的普通学习记录摘要：\n${daySummaryContext.trim()}`
      : ''

    const systemPrompt = `你是学习教练。下面是用户今晚的复盘对话和可选的今日学习记录摘要。请提取结构化要点，严格返回 JSON：
{
  "title": "今日复盘的简短标题，不超过 20 字",
  "takeaways": ["今天学到/想清楚的事，每条不超过 30 字"],
  "questions": ["用户提到不懂/卡住的地方，每条不超过 30 字"],
  "plan": ["明天/接下来打算做什么，每条不超过 30 字"]
}
提取规则：
1. 优先从对话中提取用户确认过的内容
2. 如果对话内容很少或用户没说什么有价值的，从今日学习记录摘要中提取要点，帮用户补全卡片
3. 学到：即使用户没明说，也可以根据学习记录推断今天接触了哪些知识点
4. 困惑：只保留用户明确表达过的，没有就不填
5. 明日：如果用户没提计划，可以根据今天的学习内容给出合理建议
6. 不要因为用户回答敷衍就返回全空，你的职责是帮用户把复盘做完整${daySummaryHint}`

    try {
      const response = await this.chat(dialogue, systemPrompt, true)
      const json = this.extractJSON(response)
      const result: ReflectionSummaryResult = {
        title: (json.title as string) ?? '今日复盘',
        takeaways: (json.takeaways as string[]) ?? [],
        questions: (json.questions as string[]) ?? [],
        plan: (json.plan as string[]) ?? []
      }
      return result
    } catch (err) {
      console.error('[LongCatService] reflectionSummary error:', err)
      return { title: '今日复盘', takeaways: [], questions: [], plan: [] }
    }
  }

  /* ==================== 内部方法 ==================== */

  // 延迟工具方法
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }

  // LongCat OpenAI 兼容接口调用
  private async callLongCatAPI(
    messages: LongCatChatMessage[],
    useJsonFormat: boolean,
    useLite: boolean
  ): Promise<LongCatResponse> {
    if (!this.networkService.getIsOnline()) {
      throw new Error('OFFLINE')
    }

    // 极小间隔限速，避免突发请求
    const now = Date.now()
    const sinceLast = now - this.lastRequestTime
    if (sinceLast < this.minRequestInterval) {
      await this.sleep(this.minRequestInterval - sinceLast)
    }
    this.lastRequestTime = Date.now()

    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()

      const requestBody: LongCatRequestBody = {
        model: useLite ? this.longCatLiteModel : this.longCatChatModel,
        messages: messages,
        max_tokens: 2048,
        temperature: 0.7
      }
      if (useJsonFormat) {
        const jsonFormat: LongCatResponseFormat = { type: 'json_object' }
        requestBody.response_format = jsonFormat
      }
      // LongCat 不需要 thinking 字段，删掉避免兼容问题
      requestBody.thinking = undefined

      httpRequest.request(
        this.longCatBaseUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.longCatApiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: 30000,
          readTimeout: 60000
        },
        (err, data) => {
          httpRequest.destroy()
          if (err) {
            reject(err)
            return
          }
          if (data.responseCode !== 200) {
            reject(new Error(`LongCat ${data.responseCode}: ${data.result}`))
            return
          }
          try {
            const result = JSON.parse(data.result as string) as LongCatResponse
            resolve(result)
          } catch (parseErr) {
            reject(parseErr)
          }
        }
      )
    })
  }

  // 解析 AI 回复，提取结构化数据
  private parseIntentResponse(response: string): IntentResult {
    try {
      const json = this.extractJSON(response)

      const extracted: ExtractedInfo = {
        goals: (json.goals as string[]) ?? [],
        todos: (json.todos as string[]) ?? [],
        keywords: (json.keywords as string[]) ?? [],
        emotion: (json.emotion as string) ?? '',
        emotionScore: (json.emotionScore as number) ?? 3
      }

      const result: IntentResult = {
        type: (json.type as 'goal' | 'todo' | 'emotion' | 'question' | 'chat') ?? 'chat',
        content: response,
        confidence: 0.8,
        extracted: extracted
      }
      return result
    } catch (err) {
      const fallbackResult: IntentResult = {
        type: 'chat',
        content: response,
        confidence: 0.5
      }
      return fallbackResult
    }
  }

  // AI 回复可能夹杂文字，需要提取 JSON 部分
  private extractJSON(text: string): Record<string, Object> {
    try {
      return JSON.parse(text)
    } catch {
      // 回复格式: "这是分析结果：{...}"，需要正则提取
      const jsonMatch = text.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[0])
        } catch {
          return {}
        }
      }
      return {}
    }
  }
}
