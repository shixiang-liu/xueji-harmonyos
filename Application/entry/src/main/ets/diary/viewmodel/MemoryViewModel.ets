// ============================================================================
// 记忆系统 ViewModel - Memory Management
// ============================================================================
// 职责：从日记中提取关键词，分析学习阻碍，生成知识星图数据
// 存储：关键词数据通过 CloudDBService 同步到云端
// 算法：使用预定义词库进行快速匹配，适合实时分析场景
// ============================================================================

import { CloudDBService } from '../../common/services/CloudDBService'
import { LongCatService } from '../../common/services/LongCatService'
import { Memory } from '../model/Memory'
import { Diary } from '../../diary/model/Diary'
import { PreferencesUtil } from '../../common/utils/PreferencesUtil'
import { NoteItem } from '../../diary/model/NoteItem'
import common from '@ohos.app.ability.common'

// ============================================================================
// 类型定义
// ============================================================================

// 阻碍分析结果 - 用于展示学习阻碍的统计信息
export interface ObstacleAnalysis {
  keyword: string      // 阻碍关键词
  count: number        // 出现次数
  percentage: number   // 占比百分比
}

// 提取的关键词 - 带分类标签
export interface ExtractedKeyword {
  word: string
  category: 'obstacle' | 'goal' | 'emotion' | 'general'
}

// 关键词频率 - 简化版，用于 UI 展示
export interface KeywordFrequency {
  keyword: string
  count: number
}

// 星图数据项 - 用于知识星图展示
export interface StarMapDataItem {
  keyword: string
  weight: number
}

// ============================================================================
// ViewModel 实现
// ============================================================================

export class MemoryViewModel {
  private static instance: MemoryViewModel | null = null
  private cloudDBService: CloudDBService
  private longCatService: LongCatService

  // 阻碍词库（仅用于离线备用）
  private static readonly OBSTACLE_KEYWORDS: string[] = [
    '手机', '游戏', '抖音', '微信', '视频', '刷剧',
    '熬夜', '失眠', '疲惫', '困', '累',
    '焦虑', '压力', '烦躁', '无聊',
    '拖延', '懒', '不想学', '分心', '走神'
  ]

  // 目标词库
  private static readonly GOAL_KEYWORDS: string[] = [
    '我要', '我想', '计划', '目标', '打算',
    '决定', '准备', '必须', '一定要', '希望'
  ]

  constructor() {
    this.cloudDBService = CloudDBService.getInstance()
    this.longCatService = LongCatService.getInstance()
  }

  /** 获取单例实例（推荐使用） */
  static getInstance(): MemoryViewModel {
    if (!MemoryViewModel.instance) {
      MemoryViewModel.instance = new MemoryViewModel()
    }
    return MemoryViewModel.instance
  }

  // ==================== 关键词提取 ====================

  // 从文本中提取关键词
  // 使用简单的 includes 匹配，速度快，适合实时分析
  // 如果需要更精准的分析，可以接入 LongCatService 的 AI 分析
  extractKeywords(text: string): ExtractedKeyword[] {
    const keywords: ExtractedKeyword[] = []

    // 遍历阻碍词库
    for (const word of MemoryViewModel.OBSTACLE_KEYWORDS) {
      if (text.includes(word)) {
        keywords.push({ word, category: 'obstacle' })
      }
    }

    // 遍历目标词库
    for (const word of MemoryViewModel.GOAL_KEYWORDS) {
      if (text.includes(word)) {
        keywords.push({ word, category: 'goal' })
      }
    }

    return keywords
  }

  // ==================== 关键词存储 ====================

  // 保存单个关键词
  // 如果关键词已存在，增加权重（出现频率越高权重越大）
  // 权重用于知识星图的节点大小
  async saveKeyword(keyword: string): Promise<boolean> {
    try {
      const memories = await this.cloudDBService.queryAllMemories()
      let memory = memories.find(m => m.keyword === keyword)

      if (memory) {
        // 已存在 - 增加权重
        memory.weight = (memory.weight ?? 1) + 1
      } else {
        // 新建记忆
        memory = new Memory()
        memory.id = this.generateId()
        memory.keyword = keyword
        memory.weight = 1
      }

      const result = await this.cloudDBService.upsertMemory(memory)
      return result > 0
    } catch (err) {
      console.error('[MemoryViewModel] 保存关键词失败:', err)
      return false
    }
  }

  // 批量保存关键词
  // 通常在日记保存后调用，一次性保存所有提取的关键词
  async saveKeywords(keywords: string[]): Promise<number> {
    let successCount = 0
    for (const keyword of keywords) {
      const success = await this.saveKeyword(keyword)
      if (success) successCount++
    }
    return successCount
  }

  // ==================== 数据查询 ====================

  // 获取所有记忆，按权重降序排列
  // 权重高的关键词排在前面，在星图中显示更大
  async getAllMemories(): Promise<Memory[]> {
    try {
      const memories = await this.cloudDBService.queryAllMemories()
      return memories.sort((a, b) => (b.weight ?? 0) - (a.weight ?? 0))
    } catch (err) {
      console.error('[MemoryViewModel] 获取记忆失败:', err)
      return []
    }
  }

  // 获取知识星图数据
  // useCacheFirst=true 时先使用本机缓存快速展示，同时 CloudDB 仍是同步主链路
  async getStarMapData(context?: common.Context, useCacheFirst: boolean = true): Promise<StarMapDataItem[]> {
    // 1) 本机缓存快速展示（用于 CloudDB 初始化或网络异常场景）
    if (useCacheFirst && context) {
      try {
        const local = await this.extractKeywordsFromLocalDiaries(context)
        if (local.length > 0) {
          return local
        }
      } catch (err) {
        console.warn('[MemoryViewModel] 本地星图数据提取失败，尝试云端:', err)
      }
    }

    // 2) 云端 CloudDB
    try {
      const memories = await this.getAllMemories()
      if (memories.length > 0) {
        const result: StarMapDataItem[] = []
        for (const m of memories) {
          const item: StarMapDataItem = {
            keyword: m.keyword ?? '',
            weight: m.weight ?? 1
          }
          result.push(item)
        }
        return result
      }
    } catch (err) {
      console.warn('[MemoryViewModel] 从 CloudDB 获取星图数据失败:', err)
    }

    // 3) 云端无数据或失败，再次尝试本机缓存（非 useCacheFirst 场景或二次补偿）
    if (context) {
      try {
        const local = await this.extractKeywordsFromLocalDiaries(context)
        if (local.length > 0) {
          return local
        }
      } catch (err) {
        console.error('[MemoryViewModel] 从本地日记提取关键词失败:', err)
      }
    }

    // 4) 都失败则返回空数组（页面会使用模拟数据）
    return []
  }

  // 从本机缓存日记提取关键词（作为 CloudDB 暂不可用时的补偿展示）
  private async extractKeywordsFromLocalDiaries(context: common.Context): Promise<StarMapDataItem[]> {
    try {
      // 从本地 Preferences 加载日记
      const notes = await PreferencesUtil.loadNotes(context)
      
      if (notes.length === 0) {
        return []
      }

      // 统计关键词出现频率
      const keywordCount: Map<string, number> = new Map()
      
      for (const note of notes) {
        // 提取日记内容（可能是文本或 JSON）
        let content = ''
        if (typeof note.content === 'string') {
          content = note.content
        } else if (note.content) {
          content = JSON.stringify(note.content)
        }

        // 提取关键词
        const keywords = this.extractKeywords(content)
        for (const kw of keywords) {
          const count = keywordCount.get(kw.word) || 0
          keywordCount.set(kw.word, count + 1)
        }

        // 也提取标题中的关键词
        if (note.title) {
          const titleKeywords = this.extractKeywords(note.title)
          for (const kw of titleKeywords) {
            const count = keywordCount.get(kw.word) || 0
            keywordCount.set(kw.word, count + 1)
          }
        }
      }

      // 转换为 StarMapDataItem 格式
      const result: StarMapDataItem[] = []
      keywordCount.forEach((weight, keyword) => {
        result.push({ keyword, weight })
      })

      // 按权重降序排列
      return result.sort((a, b) => b.weight - a.weight)
    } catch (err) {
      console.error('[MemoryViewModel] 从本地日记提取关键词失败:', err)
      return []
    }
  }

  // ==================== 阻碍分析 ====================

  // 分析最近 N 天的学习阻碍
  // 扫描日记内容，统计阻碍词出现频率
  // 返回按出现次数排序的分析结果
  // 优先从 CloudDB 获取，失败则从本地日记分析
  async analyzeObstacles(days: number = 7, context?: common.Context): Promise<ObstacleAnalysis[]> {
    try {
      // 1. 优先尝试从 CloudDB 获取日记
      const diaries = await this.cloudDBService.getDiariesByTime()
      
      if (diaries.length > 0) {
        // 计算时间截止点
        const now = Date.now()
        const cutoff = now - days * 24 * 60 * 60 * 1000

        // 筛选指定时间范围内的日记
        const recentDiaries = diaries.filter(d => (d.create_time ?? 0) >= cutoff)

        // 统计每个阻碍词的出现次数
        const obstacleCount: Map<string, number> = new Map()
        let totalOccurrences = 0

        for (const diary of recentDiaries) {
          const content = diary.content ?? ''

          // 遍历阻碍词库，统计每个词的出现次数
          for (const word of MemoryViewModel.OBSTACLE_KEYWORDS) {
            const regex = new RegExp(word, 'g')
            const matches = content.match(regex)
            if (matches) {
              const count = matches.length
              obstacleCount.set(word, (obstacleCount.get(word) ?? 0) + count)
              totalOccurrences += count
            }
          }
        }

        // 转换为分析结果数组
        const results: ObstacleAnalysis[] = []
        obstacleCount.forEach((count, keyword) => {
          results.push({
            keyword,
            count,
            percentage: totalOccurrences > 0 ? Math.round((count / totalOccurrences) * 100) : 0
          })
        })

        // 按出现次数降序排列
        return results.sort((a, b) => b.count - a.count)
      }
    } catch (err) {
      console.warn('[MemoryViewModel] 从 CloudDB 分析阻碍失败，尝试本地数据:', err)
    }

    // 2. CloudDB 失败或无数据，从本机缓存日记分析
    if (context) {
      try {
        return await this.analyzeObstaclesFromLocalDiaries(days, context)
      } catch (err) {
        console.error('[MemoryViewModel] 从本地日记分析阻碍失败:', err)
      }
    }

    return []
  }

  // 从本机缓存日记分析阻碍（作为 CloudDB 暂不可用时的补偿展示）
  private async analyzeObstaclesFromLocalDiaries(days: number, context: common.Context): Promise<ObstacleAnalysis[]> {
    try {
      // 从本地 Preferences 加载日记
      const notes = await PreferencesUtil.loadNotes(context)
      
      if (notes.length === 0) {
        return []
      }

      // 计算时间截止点
      const now = Date.now()
      const cutoff = now - days * 24 * 60 * 60 * 1000

      // 筛选指定时间范围内的日记
      const recentNotes = notes.filter((note: NoteItem) => {
        const noteTime: number = note.createTime || note.lastModifiedTime || 0
        return noteTime >= cutoff
      })

      // 统计每个阻碍词的出现次数
      const obstacleCount: Map<string, number> = new Map()
      let totalOccurrences = 0

      for (const note of recentNotes) {
        // 提取日记内容
        let content = ''
        if (typeof note.content === 'string') {
          content = note.content
        } else if (note.content) {
          content = JSON.stringify(note.content)
        }
        
        // 也检查标题
        if (note.title) {
          content += ' ' + note.title
        }

        // 遍历阻碍词库，统计每个词的出现次数
        for (const word of MemoryViewModel.OBSTACLE_KEYWORDS) {
          const regex = new RegExp(word, 'g')
          const matches = content.match(regex)
          if (matches) {
            const count = matches.length
            obstacleCount.set(word, (obstacleCount.get(word) ?? 0) + count)
            totalOccurrences += count
          }
        }
      }

      // 转换为分析结果数组
      const results: ObstacleAnalysis[] = []
      obstacleCount.forEach((count, keyword) => {
        results.push({
          keyword,
          count,
          percentage: totalOccurrences > 0 ? Math.round((count / totalOccurrences) * 100) : 0
        })
      })

      // 按出现次数降序排列
      return results.sort((a, b) => b.count - a.count)
    } catch (err) {
      console.error('[MemoryViewModel] 从本地日记分析阻碍失败:', err)
      return []
    }
  }

  // 获取最主要的学习阻碍
  // 用于 Dashboard 展示，只需要知道最影响学习的那个因素
  async getTopObstacle(days: number = 7, context?: common.Context): Promise<KeywordFrequency | null> {
    const obstacles = await this.analyzeObstacles(days, context)
    if (obstacles.length === 0) return null
    return {
      keyword: obstacles[0].keyword,
      count: obstacles[0].count
    }
  }

  // 生成阻碍点分析报告（使用LLM真实分析）
  async generateObstacleReport(days: number = 7, context?: common.Context): Promise<string> {
    // 收集日记内容
    const diaryContents: string[] = []
    
    try {
      // 优先从 CloudDB 获取
      const diaries = await this.cloudDBService.getDiariesByTime()
      const now = Date.now()
      const cutoff = now - days * 24 * 60 * 60 * 1000
      
      for (const diary of diaries) {
        if ((diary.create_time ?? 0) >= cutoff && diary.content) {
          diaryContents.push(diary.content)
        }
      }
    } catch (err) {
      console.warn('[MemoryViewModel] CloudDB获取日记失败:', err)
    }
    
    // 如果 CloudDB 暂无数据，使用本机缓存补偿展示
    if (diaryContents.length === 0 && context) {
      try {
        const notes = await PreferencesUtil.loadNotes(context)
        const now = Date.now()
        const cutoff = now - days * 24 * 60 * 60 * 1000
        
        for (const note of notes) {
          const noteTime = note.createTime || note.lastModifiedTime || 0
          if (noteTime >= cutoff) {
            let content = ''
            if (typeof note.content === 'string') content = note.content
            else if (note.content) content = JSON.stringify(note.content)
            if (content) diaryContents.push(content)
          }
        }
      } catch (err) {
        console.warn('[MemoryViewModel] 本地日记获取失败:', err)
      }
    }
    
    if (diaryContents.length === 0) {
      return `过去 ${days} 天内没有日记，无法分析学习阻碍。`
    }
    
    // 使用LLM分析
    try {
      const result = await this.longCatService.analyzeObstacles(diaryContents)
      return result.report
    } catch (err) {
      console.error('[MemoryViewModel] LLM分析失败:', err)
      // 降级使用关键词分析
      const obstacles = await this.analyzeObstacles(days, context)
      if (obstacles.length === 0) {
        return `过去 ${days} 天内，没有发现明显的学习阻碍。继续保持！`
      }
      const top3 = obstacles.slice(0, 3)
      let report = `过去 ${days} 天学习阻碍分析：\n\n`
      top3.forEach((o, index) => {
        report += `${index + 1}. "${o.keyword}" 出现 ${o.count} 次\n`
      })
      report += `\n建议：尝试减少 "${top3[0].keyword}" 的影响，提高专注度。`
      return report
    }
  }

  // ==================== 数据管理 ====================

  // 清除所有记忆数据
  // 用于重置分析或用户主动清除数据
  // 谨慎使用，数据删除后无法恢复
  async clearAllMemories(): Promise<boolean> {
    try {
      const memories = await this.cloudDBService.queryAllMemories()
      for (const memory of memories) {
        await this.cloudDBService.deleteMemory(memory)
      }
      return true
    } catch (err) {
      console.error('[MemoryViewModel] 清除记忆失败:', err)
      return false
    }
  }

  // ==================== 工具方法 ====================

  // 生成唯一 ID
  // 格式：mem_时间戳_随机字符串
  // 确保在分布式环境下也不会冲突
  private generateId(): string {
    return `mem_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }
}
