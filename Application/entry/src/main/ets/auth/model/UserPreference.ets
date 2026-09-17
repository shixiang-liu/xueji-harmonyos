// ============================================================================
// 用户偏好数据模型 - UserPreference
// ============================================================================
// 用于存储用户个性化设置
// 如：情绪-白噪音偏好、学习时间偏好、通知偏好等
// ============================================================================

import { cloudDatabase } from '@kit.CloudFoundationKit'

@Observed
export class UserPreference extends cloudDatabase.DatabaseObject {
  // 偏好唯一标识
  public id: string = ''
  
  // 所属用户 ID
  public user_id: string = ''
  
  // 偏好键名
  public pref_key: string = ''
  
  // 偏好值（JSON 序列化）
  public pref_value: string = ''
  
  // 创建时间戳
  public create_time: number = 0
  
  // 更新时间戳
  public update_time: number = 0

  constructor() {
    super()
  }

  // CloudDB 主键字段
  getPrimaryKeyValue(): string {
    return this.id
  }
}

// ============================================================================
// 常用偏好键名常量
// ============================================================================
export class PreferenceKeys {
  // 情绪-白噪音映射偏好
  static readonly EMOTION_NOISE_MAP = 'emotion_noise_map'
  
  // 学习时间偏好（早起型/夜猫子）
  static readonly STUDY_TIME_PREF = 'study_time_preference'
  
  // 通知时间段偏好
  static readonly NOTIFICATION_HOURS = 'notification_hours'
  
  // 主题偏好（亮/暗/跟随系统）
  static readonly THEME_MODE = 'theme_mode'
  
  // 最近一次情绪状态
  static readonly LAST_MOOD = 'last_mood'
}
