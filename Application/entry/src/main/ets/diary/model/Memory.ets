// ============================================================================
// 记忆/关键词数据模型 - Memory
// ============================================================================
// 对应 CloudDB 表：Memory
// 主键：id
// 用途：存储从日记中提取的关键词，用于知识星图和学习阻碍分析
// ============================================================================

import { cloudDatabase } from '@kit.CloudFoundationKit'

@Observed
export class Memory extends cloudDatabase.DatabaseObject {
  // 记忆唯一标识
  public id: string = ''
  
  // 所属用户 ID
  public user_id: string = ''
  
  // 关键词文本
  public keyword: string = ''
  
  // 权重（出现频次，决定星图大小）
  public weight: number = 1
  
  // 记忆类型：obstacle（阻碍）| goal（目标）| emotion（情绪）| general（通用）
  public memory_type: string = 'general'
  
  // 关联的日记 ID 列表（JSON 数组）
  public source_diary_ids: string = '[]'
  
  // 最近出现时间（用于时间衰减算法）
  public last_seen_time: number = 0
  
  // 创建时间戳
  public create_time: number = 0
  
  // 更新时间戳
  public update_time: number = 0
  
  // 同步状态：synced | pending | conflict
  public sync_status: string = 'synced'

  constructor() {
    super()
  }

  // CloudDB 必需：返回对象类型名称（与 AGC 控制台定义的表名一致）
  naturalbase_ClassName(): string {
    return 'Memory'
  }

  // CloudDB 主键字段
  getPrimaryKeyValue(): string {
    return this.id
  }
}
