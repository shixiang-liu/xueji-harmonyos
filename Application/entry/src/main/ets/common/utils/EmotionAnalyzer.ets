/**
 * @file EmotionAnalyzer.ets
 * @description 情绪分析工具 - 使用百度 NLP API 分析文本情绪
 */
import http from '@ohos.net.http'

interface BaiduTokenResponse {
  access_token?: string
  expires_in?: number
  error?: string
  error_description?: string
}

interface BaiduSentimentItem {
  sentiment?: number // 0:负面 1:中性 2:正面
  confidence?: number
  positive_prob?: number
  negative_prob?: number
}

interface BaiduSentimentResponse {
  error_code?: number
  error_msg?: string
  text?: string
  items?: BaiduSentimentItem[]
}

interface BaiduSentimentRequest {
  text: string
}

/** 情绪分析结果 */
export interface EmotionAnalysisResult {
  emotionKey: string
  emotionLabel: string
  emotionEmoji: string
  weatherLabel: string
  weatherIcon: string
  colorHex: string
  confidence: number
}

/** 情绪预设 */
export interface EmotionPreset {
  key: string
  label: string
  emoji: string
  color: string
  weather: string
  weatherIcon: string
}

/** 默认情绪预设列表 */
export const EMOTION_PRESETS: EmotionPreset[] = [
  { key: 'happy', label: '开心', emoji: '😊', color: '#FF6F91', weather: '晴', weatherIcon: '☀️' },
  { key: 'excited', label: '兴奋', emoji: '🤩', color: '#FF8A00', weather: '晴', weatherIcon: '🌤' },
  { key: 'calm', label: '平静', emoji: '🙂', color: '#8470FF', weather: '多云', weatherIcon: '⛅' },
  { key: 'grateful', label: '感激', emoji: '🥰', color: '#FF7F24', weather: '晴', weatherIcon: '🌈' },
  { key: 'sad', label: '难过', emoji: '😢', color: '#1E88E5', weather: '小雨', weatherIcon: '🌧' },
  { key: 'anxious', label: '焦虑', emoji: '😟', color: '#66CDAA', weather: '阴', weatherIcon: '☁️' },
  { key: 'angry', label: '生气', emoji: '😡', color: '#E53935', weather: '雷阵雨', weatherIcon: '⛈' }
]

/**
 * 情绪分析器 - 调用百度 NLP 情感分析 API
 */
export class EmotionAnalyzer {
  private static instance: EmotionAnalyzer | null = null

  // 百度情感分析配置 (可替换为自己的 API Key)
  private readonly apiKey: string = '' // 从本地配置注入，勿提交真实 Key
  private readonly secretKey: string = '' // 从本地配置注入，勿提交真实 Key
  private readonly tokenUrl: string = 'https://aip.baidubce.com/oauth/2.0/token'
  private readonly sentimentUrl: string = 'https://aip.baidubce.com/rpc/2.0/nlp/v1/sentiment_classify'

  private cachedToken: string = ''
  private tokenExpireAt: number = 0

  private constructor() {}

  /** 获取单例实例 */
  public static getInstance(): EmotionAnalyzer {
    if (!EmotionAnalyzer.instance) {
      EmotionAnalyzer.instance = new EmotionAnalyzer()
    }
    return EmotionAnalyzer.instance
  }

  /** 分析文本情绪 */
  async analyze(text: string): Promise<EmotionAnalysisResult | null> {
    if (!text || text.trim().length === 0) {
      return null
    }

    const normalizedText = this.prepareText(text)

    try {
      const token = await this.getAccessToken()
      if (!token) {
        throw new Error('无法获取百度情感分析的 access_token')
      }

      const url = `${this.sentimentUrl}?charset=UTF-8&access_token=${token}`
      const requestPayload: BaiduSentimentRequest = {
        text: normalizedText
      }

      const client = http.createHttp()
      try {
        const res = await client.request(url, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json;charset=UTF-8',
            'Accept': 'application/json'
          },
          extraData: JSON.stringify(requestPayload),
          connectTimeout: 15000,
          readTimeout: 20000
        })

        console.info(`[EmotionAnalyzer] 响应码: ${res.responseCode}`)

        if (res.responseCode !== 200) {
          throw new Error(`百度情感分析 HTTP错误: ${res.responseCode}`)
        }

        const responseText: string = typeof res.result === 'string' ? res.result : JSON.stringify(res.result)
        console.info(`[EmotionAnalyzer] 响应: ${responseText}`)

        const data: BaiduSentimentResponse = JSON.parse(responseText)

        if (data.error_code && data.error_code !== 0) {
          console.error(`[EmotionAnalyzer] API错误: ${data.error_code} - ${data.error_msg}`)
          if (data.error_code === 110 || data.error_code === 111) {
            this.cachedToken = ''
            this.tokenExpireAt = 0
          }
          throw new Error(data.error_msg || `百度情感分析错误: ${data.error_code}`)
        }

        if (!data.items || data.items.length === 0) {
          throw new Error('百度情感分析返回为空')
        }

        const item = data.items[0]
        return this.mapResult(item)
      } finally {
        client.destroy()
      }
    } catch (error) {
      const message = this.formatError(error)
      console.error('[EmotionAnalyzer] 分析失败:', message)
      throw new Error(message)
    }
  }

  /** 准备文本 */
  private prepareText(text: string): string {
    const trimmed = text.trim()
    if (trimmed.length <= 900) {
      return trimmed
    }
    return trimmed.substring(0, 900)
  }

  /** 获取 Access Token */
  private async getAccessToken(): Promise<string> {
    const now = Date.now()
    if (this.cachedToken && now < this.tokenExpireAt - 5 * 60 * 1000) {
      return this.cachedToken
    }

    console.info('[EmotionAnalyzer] 获取百度 Access Token...')

    const client = http.createHttp()
    try {
      const formBody = `grant_type=client_credentials&client_id=${encodeURIComponent(this.apiKey)}&client_secret=${encodeURIComponent(this.secretKey)}`

      const res = await client.request(this.tokenUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        },
        extraData: formBody,
        connectTimeout: 15000,
        readTimeout: 15000
      })

      if (res.responseCode !== 200) {
        throw new Error(`获取百度access_token失败: HTTP ${res.responseCode}`)
      }

      const responseText: string = typeof res.result === 'string' ? res.result : JSON.stringify(res.result)
      const data: BaiduTokenResponse = JSON.parse(responseText)

      if (data.error) {
        throw new Error(`百度Token认证失败: ${data.error} - ${data.error_description}`)
      }

      if (!data.access_token) {
        throw new Error('百度access_token返回为空')
      }

      this.cachedToken = data.access_token
      const expiresIn = data.expires_in ? data.expires_in * 1000 : 2592000 * 1000
      this.tokenExpireAt = Date.now() + expiresIn

      console.info('[EmotionAnalyzer] Access Token 获取成功')
      return this.cachedToken
    } catch (error) {
      const message = this.formatError(error)
      console.error('[EmotionAnalyzer] Token获取失败:', message)
      this.cachedToken = ''
      this.tokenExpireAt = 0
      throw new Error(message)
    } finally {
      client.destroy()
    }
  }

  /** 清除Token缓存 */
  public clearTokenCache(): void {
    this.cachedToken = ''
    this.tokenExpireAt = 0
    console.info('[EmotionAnalyzer] Token缓存已清除')
  }

  /** 映射API结果到情绪结果 */
  private mapResult(item: BaiduSentimentItem): EmotionAnalysisResult {
    const sentiment = item.sentiment ?? 1
    const confidence = item.confidence ?? 0.7
    const positiveProb = item.positive_prob ?? 0.5
    const negativeProb = item.negative_prob ?? 0.5

    if (sentiment === 2) { // 正面
      if (positiveProb > 0.85) {
        return this.buildResult('excited', '兴奋', '🤩', '#FF8A00', '晴', '🌤', confidence)
      }
      return this.buildResult('happy', '开心', '😊', '#FF6F91', '晴', '☀️', confidence)
    } else if (sentiment === 0) { // 负面
      if (negativeProb > 0.65) {
        return this.buildResult('sad', '难过', '😢', '#1E88E5', '小雨', '🌧', confidence)
      }
      return this.buildResult('anxious', '焦虑', '😟', '#66CDAA', '阴', '☁️', confidence)
    }

    // 中性
    return this.buildResult('calm', '平静', '🙂', '#8470FF', '多云', '⛅', confidence)
  }

  /** 构建结果对象 */
  private buildResult(
    emotionKey: string,
    emotionLabel: string,
    emotionEmoji: string,
    colorHex: string,
    weatherLabel: string,
    weatherIcon: string,
    confidence: number
  ): EmotionAnalysisResult {
    return {
      emotionKey,
      emotionLabel,
      emotionEmoji,
      colorHex,
      weatherLabel,
      weatherIcon,
      confidence
    }
  }

  /** 格式化错误信息 */
  private formatError(error: Object | string | number | boolean | null | undefined | Error): string {
    if (error instanceof Error) {
      return error.message
    }
    if (error === undefined || error === null) {
      return '未知错误'
    }
    if (typeof error === 'string') {
      return error
    }
    if (typeof error === 'number' || typeof error === 'boolean') {
      return String(error)
    }
    try {
      return JSON.stringify(error)
    } catch (jsonErr) {
      return '[无法序列化错误对象]'
    }
  }

  /** 根据key获取情绪预设 */
  public static getPresetByKey(key: string): EmotionPreset {
    return EMOTION_PRESETS.find(item => item.key === key) || EMOTION_PRESETS[2]
  }

  /** 根据label获取情绪预设 */
  public static getPresetByLabel(label: string): EmotionPreset {
    return EMOTION_PRESETS.find(item => item.label === label) || EMOTION_PRESETS[2]
  }
}
