// ============================================================================
// 目标数据模型 - Goal
// ============================================================================
// 对应 CloudDB 表：Goal
// 主键：id
// 状态：0=未开始, 1=进行中, 2=已完成, 3=已过期
// ============================================================================

import { cloudDatabase } from '@kit.CloudFoundationKit'

@Observed
export class Goal extends cloudDatabase.DatabaseObject {
  // 目标唯一标识
  public id: string = ''
  
  // 所属用户 ID
  public user_id: string = ''
  
  // 目标标题
  public title: string = ''
  
  // 目标描述
  public description: string = ''
  
  // 分类标签
  public category: string = ''
  
  // 截止日期时间戳
  public deadline: number = 0
  
  // 状态：0=未开始, 1=进行中, 2=已完成, 3=已过期
  public status: number = 0
  
  // 进度百分比 0-100
  public progress: number = 0
  
  // 优先级：1=低, 2=中, 3=高
  public priority: number = 2
  
  // 关联的日记 ID（从哪篇日记提取）
  public source_diary_id: string = ''
  
  // 提醒时间戳
  public reminder_time: number = 0
  
  // 最后提及时间（用于去重）
  public last_mentioned_time: number = 0
  
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
    return 'Goal'
  }

  // CloudDB 主键字段
  getPrimaryKeyValue(): string {
    return this.id
  }
}
