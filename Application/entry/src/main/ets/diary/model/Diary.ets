// ============================================================================
// 日记数据模型 - Diary
// ============================================================================
// 对应 CloudDB 表：Diary
// 主键：id
// 存储：content 字段存储完整 NoteItem 的 JSON 序列化
// ============================================================================

import { cloudDatabase } from '@kit.CloudFoundationKit'

@Observed
export class Diary extends cloudDatabase.DatabaseObject {
  // 日记唯一标识
  public id: string = ''
  
  // 所属用户 ID
  public user_id: string = ''
  
  // 日记标题
  public title: string = ''
  
  // 日记内容（存储完整 NoteItem 的 JSON）
  public content: string = ''
  
  // 情绪标签
  public mood: string = ''
  
  // 情绪分数 1-5
  public mood_score: number = 3
  
  // 情绪表情
  public mood_emoji: string = ''
  
  // 音频文件路径（本地或云端 URL）
  public audio_url: string = ''
  
  // 音频转写文本
  public transcription: string = ''
  
  // AI 提取的关键词（JSON 数组）
  public keywords: string = '[]'
  
  // AI 分析结果（JSON）
  public ai_analysis: string = ''
  
  // 创建时间戳
  public create_time: number = 0
  
  // 更新时间戳
  public update_time: number = 0
  
  // 删除时间戳（回收站功能）
  public deleted_time: number = 0
  
  // 同步状态：synced | pending | conflict
  public sync_status: string = 'synced'

  constructor() {
    super()
  }

  // CloudDB 必需：返回对象类型名称（与 AGC 控制台定义的表名一致）
  naturalbase_ClassName(): string {
    return 'Diary'
  }

  // CloudDB 主键字段
  getPrimaryKeyValue(): string {
    return this.id
  }
}
