// ============================================================================
// 用户数据模型 - User
// ============================================================================
// 对应 CloudDB 表：User
// 主键：uid（AGC 用户ID，来自邮箱认证或华为账号认证）
// ============================================================================

import { cloudDatabase } from '@kit.CloudFoundationKit'

@Observed
export class User extends cloudDatabase.DatabaseObject {
  // 用户唯一标识（AGC uid）
  public uid: string = ''

  // 邮箱地址（邮箱认证用户）
  public email: string = ''
  
  // 手机号（预留字段）
  public phone: string = ''
  
  // 密码哈希（邮箱密码登录用）
  public password_hash: string = ''
  
  // 昵称
  public nickname: string = ''
  
  // 头像路径（本地路径或云端 URL）
  public avatar: string = ''
  
  // 用户设置（JSON 序列化存储）
  public settings: string = ''
  
  // 创建时间戳
  public create_time: number = 0
  
  // 最后登录时间
  public last_login: number = 0
  
  // 同步状态：synced | pending | conflict
  public sync_status: string = 'synced'

  constructor() {
    super()
  }

  // CloudDB 必需：返回对象类型名称（与 AGC 控制台定义的表名一致）
  naturalbase_ClassName(): string {
    return 'User'
  }

  // CloudDB 主键字段
  getPrimaryKeyValue(): string {
    return this.uid
  }
}
