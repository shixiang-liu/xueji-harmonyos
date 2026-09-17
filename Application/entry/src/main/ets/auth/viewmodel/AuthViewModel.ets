// 认证服务 - 邮箱验证码登录/注册/密码重置
// 用户数据通过 CloudDBService 同步到云端
// AGConnect Auth 集成：邮箱验证码服务
import { CloudDBService } from '../../common/services/CloudDBService'
import { NotificationService } from '../../common/services/NotificationService'
import { User } from '../model/User'
import { promptAction } from '@kit.ArkUI'
import http from '@ohos.net.http'
import { PreferencesUtil } from '../../common/utils/PreferencesUtil'
import { BusinessError } from '@kit.BasicServicesKit'
// AGConnect Auth SDK
import agconnect from '@hw-agconnect/api-ohos'
import { EmailAuthProvider, EmailUserBuilder, VerifyCodeAction, VerifyCodeSettingBuilder, AGConnectUser } from '@hw-agconnect/auth-ohos'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { GestureAuthUtil } from '../utils/GestureAuthUtil'
import { mapVerificationCodeErrorMessage } from '../utils/AuthErrorMessageUtil'
// 导入 SDK 初始化状态检查
import { waitForAGCInit, isAGCInitialized } from '../../entryability/EntryAbility'

// 云函数发送验证码的响应接口
interface SendCodeResponse {
  code: number
  message: string
}

export interface AuthResult {
  success: boolean
  message: string
  user?: User
}

export interface UserCredentials {
  email?: string
  password?: string
  code?: string
  nickname?: string
  avatar?: string
}

export interface RememberedInfo {
  email: string
  password: string
  remember: boolean
}

interface StoredUserRecord {
  uid: string
  email: string
  phone: string
  password_hash: string
  nickname: string
  avatar: string
  settings: string
  create_time: number
  last_login: number
  sync_status: string
  gesture_hash?: string
}

// 密码验证结果
export interface ValidationResult {
  valid: boolean
  message: string
}

export class AuthViewModel {
  private static readonly LOCAL_USERS_KEY: string = 'auth_local_users'
  private static readonly DEMO_VERIFY_CODE_MODE: boolean = false
  private cloudDBService: CloudDBService
  private codeEmail: string = ''
  private codeExpireTime: number = 0
  // ========== 模拟验证码测试模式 ==========
  // 当邮箱服务未就绪时，启用此模式进行测试
  // 设置为 false 可切换到真实邮箱验证
  private static MOCK_MODE: boolean = false
  private mockCode: string = ''

  // ========================================

  constructor() {
    this.cloudDBService = CloudDBService.getInstance()
  }

  private getAgcUserEmail(user: AGConnectUser): string {
    try {
      return String(user.getEmail() || '').trim().toLowerCase()
    } catch (err) {
      return ''
    }
  }

  private async prepareAgcForEmailSignIn(email: string, scene: string): Promise<AGConnectUser | null> {
    try {
      const currentUser: AGConnectUser | null = await agconnect.auth().getCurrentUser()
      if (!currentUser) {
        return null
      }
      const currentEmail = this.getAgcUserEmail(currentUser)
      const targetEmail = this.normalizeEmail(email)
      if (!currentUser.isAnonymous() && currentEmail === targetEmail) {
        console.info(`[AuthViewModel] ${scene}: AGConnect已是当前邮箱用户，复用登录态 uid=${currentUser.getUid()}`)
        return currentUser
      }
      console.warn(`[AuthViewModel] ${scene}: AGConnect已有其他/匿名用户，验证码登录前先退出旧会话 uid=${currentUser.getUid()} email=${currentEmail}`)
      await agconnect.auth().signOut()
      return null
    } catch (err) {
      console.warn(`[AuthViewModel] ${scene}: 清理AGConnect旧会话失败，继续尝试验证码登录:`, JSON.stringify(err))
      return null
    }
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase()
  }

  private toStoredUser(user: User): StoredUserRecord {
    return {
      uid: user.uid,
      email: user.email,
      phone: user.phone,
      password_hash: user.password_hash,
      nickname: user.nickname,
      avatar: user.avatar,
      settings: user.settings,
      create_time: user.create_time,
      last_login: user.last_login,
      sync_status: user.sync_status,
      gesture_hash: AuthViewModel.readGestureHash(user.settings)
    }
  }

  private fromStoredUser(record: StoredUserRecord): User {
    const user = new User()
    user.uid = record.uid
    user.email = record.email
    user.phone = record.phone
    user.password_hash = record.password_hash
    user.nickname = record.nickname
    user.avatar = record.avatar
    user.settings = record.settings
    if (!AuthViewModel.readGestureHash(user.settings) && record.gesture_hash) {
      user.settings = AuthViewModel.writeGestureHash(user.settings, record.gesture_hash)
    }
    user.create_time = record.create_time
    user.last_login = record.last_login
    user.sync_status = record.sync_status
    return user
  }

  private async loadLocalUsers(): Promise<StoredUserRecord[]> {
    try {
      return await PreferencesUtil.getObject<StoredUserRecord[]>(AuthViewModel.LOCAL_USERS_KEY, [])
    } catch (err) {
      console.warn('[AuthViewModel] 读取本地用户缓存失败:', err)
      return []
    }
  }

  private async saveLocalUser(user: User): Promise<void> {
    if (!user.email) {
      return
    }

    const normalizedEmail = this.normalizeEmail(user.email)
    const users = await this.loadLocalUsers()
    const nextUsers = users.filter((record: StoredUserRecord) => this.normalizeEmail(record.email) !== normalizedEmail)
    nextUsers.push(this.toStoredUser(user))
    await PreferencesUtil.putObject<StoredUserRecord[]>(AuthViewModel.LOCAL_USERS_KEY, nextUsers)
  }

  private static readGestureHash(settings: string): string {
    if (!settings) {
      return ''
    }
    try {
      const parsed = JSON.parse(settings) as Record<string, string>
      return parsed['gesture_hash'] || ''
    } catch (err) {
      return ''
    }
  }

  private static writeGestureHash(settings: string, gestureHash: string): string {
    let parsed: Record<string, string> = {}
    if (settings) {
      try {
        parsed = JSON.parse(settings) as Record<string, string>
      } catch (err) {
        parsed = {}
      }
    }
    parsed['gesture_hash'] = gestureHash
    return JSON.stringify(parsed)
  }

  private async getLocalUserByEmail(email: string): Promise<User | null> {
    const normalizedEmail = this.normalizeEmail(email)
    const users = await this.loadLocalUsers()
    const record = users.find((item: StoredUserRecord) => this.normalizeEmail(item.email) === normalizedEmail)
    return record ? this.fromStoredUser(record) : null
  }

  async hasGesture(email: string): Promise<boolean> {
    const user = await this.getLocalUserByEmail(email)
    return !!user && !!AuthViewModel.readGestureHash(user.settings)
  }

  async saveGesture(email: string, gesture: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }
    if (!GestureAuthUtil.isValidGesture(gesture)) {
      return { success: false, message: '手势密码至少连接 4 个不重复点' }
    }

    const user = await this.getLocalUserByEmail(email)
    if (!user) {
      return { success: false, message: '用户不存在，无法设置手势' }
    }

    user.settings = AuthViewModel.writeGestureHash(user.settings, GestureAuthUtil.hashGesture(gesture))
    user.last_login = Date.now()
    await this.saveLocalUser(user)
    await this.saveLoginState(user)
    return { success: true, message: '手势密码设置成功', user: user }
  }

  async loginWithGesture(email: string, gesture: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }
    if (!GestureAuthUtil.isValidGesture(gesture)) {
      return { success: false, message: '手势密码至少连接 4 个不重复点' }
    }

    const user = await this.getLocalUserByEmail(email)
    if (!user) {
      return { success: false, message: '用户不存在' }
    }

    const savedHash = AuthViewModel.readGestureHash(user.settings)
    if (!savedHash) {
      return { success: false, message: '该账号尚未设置手势密码' }
    }
    if (savedHash !== GestureAuthUtil.hashGesture(gesture)) {
      return { success: false, message: '手势密码错误' }
    }

    user.last_login = Date.now()
    await this.saveLocalUser(user)
    await this.saveLoginState(user)
    return { success: true, message: '手势验证成功', user: user }
  }

  private async findUserByEmail(email: string): Promise<User | null> {
    const normalizedEmail = this.normalizeEmail(email)
    const cloudUser = await this.cloudDBService.getUserByEmail(normalizedEmail)
    if (cloudUser) {
      await this.saveLocalUser(cloudUser)
      return cloudUser
    }
    return await this.getLocalUserByEmail(normalizedEmail)
  }

  private async persistUser(user: User): Promise<void> {
    user.email = this.normalizeEmail(user.email)
    user.sync_status = 'pending'
    await this.saveLocalUser(user)

    const cloudResult = await this.cloudDBService.upsertUser(user)
    if (cloudResult > 0) {
      user.sync_status = 'synced'
      await this.saveLocalUser(user)
    } else {
      console.warn('[AuthViewModel] 云端用户同步失败，已保留本地用户缓存:', user.email)
    }
  }

  // 生成6位随机验证码（测试模式用）
  private generateMockCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString()
  }

  // 密码强度 0-3，用于 UI 进度条
  calculatePasswordStrength(password: string): number {
    if (!password) {
      return 0
    }
    let strength = 0
    if (password.length >= 6) {
      strength++
    }
    if (password.length >= 10) {
      strength++
    }
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) {
      strength++
    }
    if (/\d/.test(password) && /[!@#$%^&*(),.?":{}|<>]/.test(password)) {
      strength++
    }
    return Math.min(strength, 3)
  }

  // 邮箱格式验证
  validateEmail(email: string): boolean {
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
    return emailRegex.test(this.normalizeEmail(email))
  }

  // 密码 8-26 位，包含字母和数字（符合 AGConnect 要求）
  validatePassword(password: string): ValidationResult {
    if (!password || password.length < 8) {
      const result: ValidationResult = { valid: false, message: '密码至少需要8位' }
      return result
    }
    if (password.length > 26) {
      const result: ValidationResult = { valid: false, message: '密码最多26位' }
      return result
    }
    if (!/[a-zA-Z]/.test(password)) {
      const result: ValidationResult = { valid: false, message: '密码需要包含字母' }
      return result
    }
    if (!/\d/.test(password)) {
      const result: ValidationResult = { valid: false, message: '密码需要包含数字' }
      return result
    }
    const result: ValidationResult = { valid: true, message: '' }
    return result
  }

  private async sendDemoVerificationCode(email: string): Promise<AuthResult> {
    this.mockCode = this.generateMockCode()
    this.codeEmail = this.normalizeEmail(email)
    this.codeExpireTime = Date.now() + 5 * 60 * 1000

    console.info(`[AuthViewModel][DEMO_CODE] 演示验证码: ${this.mockCode} 邮箱: ${this.codeEmail}`)

    const notificationService = NotificationService.getInstance()
    const notificationSent = await notificationService.sendVerificationCodeNotification(this.mockCode)

    if (notificationSent) {
      promptAction.showToast({
        message: '验证码已发送到通知栏',
        duration: 2000
      })
    } else {
      promptAction.showDialog({
        title: '验证码',
        message: `您的验证码是：\n\n${this.mockCode}\n\n有效期5分钟`,
        buttons: [{ text: '确定', color: '#1C1917' }]
      })
    }

    return { success: true, message: '验证码已发送' }
  }

  private verifyDemoCode(email: string, code: string): AuthResult {
    if (Date.now() > this.codeExpireTime) {
      return { success: false, message: '验证码已过期，请重新获取' }
    }
    if (this.normalizeEmail(email) !== this.codeEmail) {
      return { success: false, message: '邮箱与获取验证码时不一致' }
    }
    if (code !== this.mockCode) {
      console.warn(`[AuthViewModel][DEMO_CODE] 验证码错误: 输入=${code}, 正确=${this.mockCode}`)
      return { success: false, message: '验证码错误' }
    }
    return { success: true, message: '验证成功' }
  }

  private clearLocalCode(): void {
    this.mockCode = ''
    this.codeEmail = ''
    this.codeExpireTime = 0
  }

  private createLocalUser(email: string, password: string, nickname?: string, uid?: string, avatar?: string): User {
    const normalizedEmail = this.normalizeEmail(email)
    const user = new User()
    user.uid = uid || normalizedEmail.split('@')[0]
    user.email = normalizedEmail
    user.phone = ''
    user.nickname = nickname || `用户${normalizedEmail.split('@')[0].slice(-4)}`
    user.avatar = avatar || ''
    user.password_hash = this.hashPassword(password)
    user.create_time = Date.now()
    return user
  }

  // 发送邮箱验证码。演示验证码模式只替代邮件发送，用户数据仍通过 CloudDB 同步。
  async sendVerificationCode(email: string, actionType: string = 'login'): Promise<AuthResult> {
    const normalizedEmail = this.normalizeEmail(email)
    if (!this.validateEmail(normalizedEmail)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }

    if (AuthViewModel.DEMO_VERIFY_CODE_MODE || AuthViewModel.MOCK_MODE) {
      return await this.sendDemoVerificationCode(normalizedEmail)
    }

    try {
      // 等待 AGConnect SDK 初始化完成
      hilog.info(0x0000, 'AuthViewModel', 'Waiting for AGConnect SDK initialization...')
      await waitForAGCInit()
      hilog.info(0x0000, 'AuthViewModel', 'AGConnect SDK is ready, sending verification code...')

      // 构建验证码配置（官方推荐用 VerifyCodeSettingBuilder）
      const settings = new VerifyCodeSettingBuilder()
        .setAction(actionType === 'reset' ? VerifyCodeAction.RESET_PASSWORD : VerifyCodeAction.REGISTER_LOGIN)
        .setLang('zh_CN')
        .setSendInterval(60)
        .build()

      // 调用 AGConnect Auth 发送邮箱验证码（带重试机制）
      let lastError: BusinessError | null = null
      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          hilog.info(0x0000, 'AuthViewModel', `Attempt ${attempt}: Calling requestEmailVerifyCode for ${normalizedEmail}`)
          
          const result = await agconnect.auth().requestEmailVerifyCode(normalizedEmail, settings)
          
          hilog.info(0x0000, 'AuthViewModel', `requestEmailVerifyCode succeeded, interval: ${result.getShortestInterval()}`)
          
          // 记录当前验证邮箱
          this.codeEmail = normalizedEmail
          this.codeExpireTime = Date.now() + 5 * 60 * 1000

          console.info(`[AuthViewModel] 邮箱验证码已发送至: ${normalizedEmail}`)
          return { success: true, message: '验证码已发送，请查收邮件' }
        } catch (e) {
          lastError = e as BusinessError
          hilog.error(0x0000, 'AuthViewModel', `Attempt ${attempt} failed - Code: ${lastError.code}, Message: ${lastError.message}`)
          if (attempt < 2) {
            // 等待 1.5 秒后重试
            await new Promise<void>(resolve => setTimeout(resolve, 1500))
          }
        }
      }      // 所有重试都失败
      const error = lastError!
      console.error('[AuthViewModel] 发送邮箱验证码失败:', JSON.stringify(error))

      // 根据错误码返回友好提示
      const errorCode = error.code || 0
      if (errorCode === 203818048) {
        return { success: false, message: '发送过于频繁，请稍后再试' }
      } else if (errorCode === 203818049) {
        return { success: false, message: '今日发送次数已达上限' }
      }
      return { success: false, message: `发送失败: ${error.message || '未知错误'}` }
    } catch (e) {
      const error = e as BusinessError
      console.error('[AuthViewModel] AGConnect SDK 初始化或验证码发送失败:', JSON.stringify(error))
      return { success: false, message: '邮箱验证码发送失败，请检查网络或 AGConnect 配置' }
    }
  }

  // 发送重置密码验证码
  async sendCodeForReset(email: string): Promise<AuthResult> {
    const normalizedEmail = this.normalizeEmail(email)
    if (!this.validateEmail(normalizedEmail)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }

    try {
      // 按邮箱检查用户是否存在
      const existingUser = await this.findUserByEmail(normalizedEmail)
      if (!existingUser) {
        return { success: false, message: '该邮箱未注册' }
      }
    } catch (err) {
      console.error('[AuthViewModel] 检查用户失败:', err)
    }

    // 本项目的密码登录使用自有 password_hash。这里用验证码确认邮箱归属，
    // 校验成功后更新本地/云端密码 hash，避免依赖 AGConnect 邮箱密码账号形态。
    return await this.sendVerificationCode(normalizedEmail, 'login')
  }

  // 注册时发送验证码（会检查邮箱是否已注册）
  async sendCodeForRegister(email: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }

    try {
      // 按邮箱检查用户是否已存在
      const existingUser = await this.findUserByEmail(email)
      if (existingUser) {
        return { success: false, message: '该邮箱已注册，如忘记密码请去忘记密码页面重置' }
      }
    } catch (err) {
      console.error('[AuthViewModel] 检查用户失败:', err)
    }

    return await this.sendVerificationCode(email, 'register')
  }

  // 验证邮箱验证码（不退出登录，用于注册流程）
  async verifyEmailCode(email: string, code: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }
    if (!code || code.length !== 6) {
      return { success: false, message: '请输入6位验证码' }
    }

    if (AuthViewModel.DEMO_VERIFY_CODE_MODE || AuthViewModel.MOCK_MODE) {
      return this.verifyDemoCode(email, code)
    }

    // AGConnect验证 - 使用登录验证验证码，不退出
    try {
      await waitForAGCInit()
      const currentUser = await this.prepareAgcForEmailSignIn(email, 'verifyEmailCode')
      if (currentUser) {
        console.info('[AuthViewModel] 验证码验证复用现有AGConnect登录态:', email)
        return { success: true, message: '验证成功' }
      }
      const credential = EmailAuthProvider.credentialWithVerifyCode(email, code)
      await agconnect.auth().signIn(credential)
      // 验证成功，保持登录状态，供后续register方法使用
      console.info('[AuthViewModel] 验证码验证成功，已登录AGConnect')
      return { success: true, message: '验证成功' }
    } catch (err) {
      const error = err as BusinessError
      const errorCode = error.code || 0
      console.error(`[AuthViewModel] 验证码校验失败 code=${errorCode} msg=${error.message} email=${email} input=${code}`)
      hilog.error(0x0000, 'AuthViewModel', `verifyEmailCode failed code=${errorCode} msg=${error.message}`)
      return {
        success: false,
        message: mapVerificationCodeErrorMessage(errorCode, '验证码验证失败，请检查后重试')
      }
    }
  }

  async loginWithPassword(email: string, password: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }
    if (!password) {
      return { success: false, message: '请输入密码' }
    }

    try {
      const normalizedEmail = this.normalizeEmail(email)

      // 先查云端
      const cloudUser = await this.cloudDBService.getUserByEmail(normalizedEmail)
      const cloudFailed = this.cloudDBService.lastQueryFailed
      if (cloudUser) {
        await this.saveLocalUser(cloudUser)
      }

      // 云端没有就回退本地
      let user: User | null = cloudUser
      if (!user) {
        user = await this.getLocalUserByEmail(normalizedEmail)
      }

      if (!user) {
        if (cloudFailed) {
          return { success: false, message: '网络不可用，请检查网络后重试' }
        }
        return { success: false, message: '用户不存在，请先注册' }
      }

      // 简化实现，实际应用哈希比对
      if (user.password_hash !== this.hashPassword(password)) {
        return { success: false, message: '密码错误' }
      }

      await this.saveLoginState(user)

      return { success: true, message: '登录成功', user: user }
    } catch (err) {
      console.error('[AuthViewModel] 登录失败:', err)
      return { success: false, message: '登录失败，请稍后重试' }
    }
  }

  // 验证码登录（用户不存在会自动注册）
  async loginWithCode(email: string, code: string): Promise<AuthResult> {
    if (!this.validateEmail(email)) {
      return { success: false, message: '请输入正确的邮箱地址' }
    }
    if (!code || code.length !== 6) {
      return { success: false, message: '请输入6位验证码' }
    }

    if (AuthViewModel.DEMO_VERIFY_CODE_MODE || AuthViewModel.MOCK_MODE) {
      const verifyResult = this.verifyDemoCode(email, code)
      if (!verifyResult.success) {
        return verifyResult
      }

      console.info(`[AuthViewModel][DEMO_CODE] 验证码登录成功: ${email}`)

      try {
        let user = await this.findUserByEmail(email)
        if (!user) {
          user = this.createLocalUser(email, '', undefined, `local_${this.normalizeEmail(email).split('@')[0]}_${Date.now()}`)
          await this.persistUser(user)
          console.info('[AuthViewModel][DEMO_CODE] 新用户已创建并提交云同步:', email)
        }

        await this.saveLoginState(user)
        this.clearLocalCode()

        return { success: true, message: '登录成功', user: user }
      } catch (err) {
        console.error('[AuthViewModel][DEMO_CODE] 用户操作失败:', err)
        return { success: false, message: '登录失败，请稍后重试' }
      }
    }

    try {
      // 等待 AGConnect SDK 初始化完成
      hilog.info(0x0000, 'AuthViewModel', 'Waiting for AGConnect SDK for code login...')
      await waitForAGCInit()
      const currentUser = await this.prepareAgcForEmailSignIn(email, 'loginWithCode')

      // 使用 EmailAuthProvider 创建凭证并登录
      let agcUser: AGConnectUser | null = currentUser
      if (!agcUser) {
        const credential = EmailAuthProvider.credentialWithVerifyCode(email, code)
        const signInResult = await agconnect.auth().signIn(credential)
        agcUser = signInResult.getUser()
      }

      // 获取 AGConnect 用户信息
      const agcUid: string = agcUser ? agcUser.getUid() : email

      // 查找或创建本地用户
      let user = await this.findUserByEmail(email)
      if (!user) {
        // 用户不存在，自动注册并同步到云端
        user = new User()
        user.uid = agcUid
        user.email = email
        user.phone = ''
        user.nickname = `用户${email.split('@')[0].slice(-4)}`
        user.avatar = ''
        user.password_hash = ''
        user.create_time = Date.now()
        
        // 同步到云数据库
        await this.persistUser(user)
        console.info('[AuthViewModel] AGConnect 验证码登录 - 新用户已创建并同步到云:', email)
      } else {
        console.info('[AuthViewModel] AGConnect 验证码登录 - 用户已存在:', email)
      }

      await this.saveLoginState(user)
      console.info('[AuthViewModel] AGConnect 验证码登录成功:', email)

      return { success: true, message: '登录成功', user: user }
    } catch (err) {
      const error = err as BusinessError
      console.error('[AuthViewModel] AGConnect 验证码登录失败:', JSON.stringify(error))

      // 根据 AGConnect 错误码返回友好提示
      const errorCode = error.code || 0
      if (errorCode === 10002 || String(error.message).includes('AGCInstance not inited')) {
        return { success: false, message: '网络不可用，请检查网络连接' }
      }
      return {
        success: false,
        message: mapVerificationCodeErrorMessage(errorCode, '登录失败，请稍后重试')
      }
    }
  }

  // 用户注册（验证码验证后创建用户）
  async register(credentials: UserCredentials): Promise<AuthResult> {
    const email = credentials.email
    const password = credentials.password
    const code = credentials.code
    const nickname = credentials.nickname

    if (!email || !this.validateEmail(email)) {
      const result: AuthResult = { success: false, message: '请输入正确的邮箱地址' }
      return result
    }

    const passwordCheck = this.validatePassword(password || '')
    if (!passwordCheck.valid) {
      const result: AuthResult = { success: false, message: passwordCheck.message }
      return result
    }

    if (!code || code.length !== 6) {
      const result: AuthResult = { success: false, message: '请输入6位验证码' }
      return result
    }

    if (AuthViewModel.DEMO_VERIFY_CODE_MODE || AuthViewModel.MOCK_MODE) {
      const verifyResult = this.verifyDemoCode(email, code)
      if (!verifyResult.success) {
        return verifyResult
      }

      try {
        const existingUser = await this.findUserByEmail(email)
        if (existingUser) {
          return { success: false, message: '该邮箱已注册' }
        }

        const user = this.createLocalUser(email, password!, nickname, undefined, credentials.avatar)

        await this.persistUser(user)
        console.info('[AuthViewModel][DEMO_CODE] 注册成功并提交云同步:', email)

        this.clearLocalCode()
        await this.saveLoginState(user)
        await this.saveLastLoginEmail(email)

        return { success: true, message: '注册成功', user: user }
      } catch (err) {
        console.error('[AuthViewModel][DEMO_CODE] 注册操作失败:', err)
        return { success: false, message: '注册失败，请稍后重试' }
      }
    }

    try {
      // 检查AGConnect是否已登录（verifyEmailCode已经登录了）
      const currentUser: AGConnectUser | null = await agconnect.auth().getCurrentUser()
      
      if (currentUser) {
        // 已登录，说明验证码已验证，直接创建本地用户记录
        console.info('[AuthViewModel] 检测到AGConnect已登录，直接完善用户信息')
        const agcUid: string = currentUser.getUid()
        
        // 检查本地是否已有用户
        let existingUser = await this.findUserByEmail(email)
        if (existingUser) {
          // 更新密码和昵称
          existingUser.password_hash = this.hashPassword(password!)
          existingUser.nickname = nickname || existingUser.nickname
          await this.persistUser(existingUser)
          await this.saveLoginState(existingUser)
          await this.saveLastLoginEmail(email)
          return { success: true, message: '注册成功', user: existingUser }
        }
        
        // 创建新用户
        const user = new User()
        user.uid = agcUid
        user.email = email
        user.phone = ''
        user.nickname = nickname || `用户${email.split('@')[0].slice(-4)}`
        user.avatar = credentials.avatar || ''
        user.password_hash = this.hashPassword(password!)
        user.create_time = Date.now()
        await this.persistUser(user)
        await this.saveLoginState(user)
        await this.saveLastLoginEmail(email)
        console.info('[AuthViewModel] 注册成功（基于已登录状态）:', email)
        return { success: true, message: '注册成功', user: user }
      }

      // 未登录，使用传统方式创建用户（不应该走到这里）
      console.warn('[AuthViewModel] AGConnect未登录，使用createEmailUser方式注册')
      
      // 检查本地是否已有用户（按邮箱查询）
      let existingUser = await this.findUserByEmail(email)
      if (existingUser) {
        console.info('[AuthViewModel] 用户已存在，更新密码并完善信息:', email)
        existingUser.password_hash = this.hashPassword(password!)
        existingUser.nickname = nickname || existingUser.nickname
        await this.persistUser(existingUser)
        await this.saveLoginState(existingUser)
        await this.saveLastLoginEmail(email)
        return { success: true, message: '账户信息已完善', user: existingUser }
      }

      // 使用 EmailUserBuilder 构建用户并创建
      const emailUser = new EmailUserBuilder()
        .setEmail(email)
        .setVerifyCode(code)
        .setPassword(password!)
        .build()
      await agconnect.auth().createEmailUser(emailUser)

      // 创建本地用户记录
      const user = new User()
      user.uid = email.split('@')[0]
      user.email = email
      user.phone = ''
      user.nickname = nickname || `用户${email.split('@')[0].slice(-4)}`
      user.avatar = ''
      user.password_hash = this.hashPassword(password!)
      user.create_time = Date.now()

      await this.persistUser(user)
      console.info('[AuthViewModel] AGConnect 用户注册成功:', email)

      // 注册成功后自动登录
      await this.saveLoginState(user)
      // 保存邮箱供下次登录使用
      await this.saveLastLoginEmail(email)

      return { success: true, message: '注册成功', user: user }
    } catch (err) {
      const error = err as BusinessError
      console.error('[AuthViewModel] AGConnect 注册失败:', JSON.stringify(error))

      const errorCode = error.code || 0
      if (errorCode === 203818130) {
        return { success: false, message: '验证码错误' }
      } else if (errorCode === 203818129) {
        return { success: false, message: '验证码已过期' }
      } else if (errorCode === 203818037) {
        return { success: false, message: '该邮箱已注册' }
      }
      return { success: false, message: '注册失败，请稍后重试' }
    }
  }

  // 重置密码
  async resetPassword(email: string, code: string, newPassword: string): Promise<AuthResult> {
    const normalizedEmail = this.normalizeEmail(email)
    const normalizedCode = code.trim()
    if (!this.validateEmail(normalizedEmail)) {
      const result: AuthResult = { success: false, message: '请输入正确的邮箱地址' }
      return result
    }

    if (!normalizedCode || normalizedCode.length !== 6) {
      const result: AuthResult = { success: false, message: '请输入6位验证码' }
      return result
    }

    const passwordCheck = this.validatePassword(newPassword)
    if (!passwordCheck.valid) {
      const result: AuthResult = { success: false, message: passwordCheck.message }
      return result
    }

    if (AuthViewModel.DEMO_VERIFY_CODE_MODE || AuthViewModel.MOCK_MODE) {
      const verifyResult = this.verifyDemoCode(normalizedEmail, normalizedCode)
      if (!verifyResult.success) {
        return verifyResult
      }

      try {
        const user = await this.findUserByEmail(normalizedEmail)
        if (!user) {
          return { success: false, message: '用户不存在' }
        }

        user.password_hash = this.hashPassword(newPassword)
        await this.persistUser(user)

        console.info('[AuthViewModel][DEMO_CODE] 密码重置成功并提交云同步:', normalizedEmail)

        this.clearLocalCode()

        return { success: true, message: '密码重置成功' }
      } catch (err) {
        console.error('[AuthViewModel][DEMO_CODE] 重置密码操作失败:', err)
        return { success: false, message: '重置密码失败，请稍后重试' }
      }
    }

    try {
      await waitForAGCInit()
      const currentUser: AGConnectUser | null = await agconnect.auth().getCurrentUser()
      if (currentUser && this.getAgcUserEmail(currentUser) === normalizedEmail) {
        const user = await this.findUserByEmail(normalizedEmail)
        if (!user) {
          return { success: false, message: '用户不存在' }
        }

        user.password_hash = this.hashPassword(newPassword)
        await this.persistUser(user)
        await this.saveLastLoginEmail(normalizedEmail)
        try {
          await agconnect.auth().signOut()
        } catch (signOutErr) {
          console.warn('[AuthViewModel] 重置密码后退出AGConnect会话失败:', JSON.stringify(signOutErr))
        }

        console.info('[AuthViewModel] 邮箱验证码已验证，本地密码重置成功:', normalizedEmail)
        return { success: true, message: '密码重置成功' }
      }
    } catch (verifyErr) {
      console.warn('[AuthViewModel] 未检测到已验证的邮箱会话，尝试AGConnect重置:', JSON.stringify(verifyErr))
    }

    try {
      // 使用 AGConnect Auth 重置密码
      await agconnect.auth().resetPasswordByEmail(normalizedEmail, newPassword, normalizedCode)

      // 同步更新本地用户密码
      const user = await this.findUserByEmail(normalizedEmail)
      if (user) {
        user.password_hash = this.hashPassword(newPassword)
        await this.persistUser(user)
      }

      console.info('[AuthViewModel] AGConnect 密码重置成功:', normalizedEmail)
      return { success: true, message: '密码重置成功' }
    } catch (err) {
      const error = err as BusinessError
      console.error('[AuthViewModel] AGConnect 重置密码失败:', JSON.stringify(error))

      const errorCode = error.code || 0
      return {
        success: false,
        message: mapVerificationCodeErrorMessage(errorCode, '重置失败，请稍后重试')
      }
    }
  }

  // 简化哈希，生产环境应使用 bcrypt/PBKDF2
  private hashPassword(password: string): string {
    let hash = 0
    for (let i = 0; i < password.length; i++) {
      const char = password.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash
    }
    return `hash_${Math.abs(hash).toString(16)}`
  }

  // 登录后存储用户信息到 AppStorage，供全局访问
  private async saveLoginState(user: User): Promise<void> {
    try {
      AppStorage.setOrCreate('isLoggedIn', true)
      AppStorage.setOrCreate('currentUserId', user.uid)
      AppStorage.setOrCreate('currentUserEmail', user.email || '')
      AppStorage.setOrCreate('currentUserPhone', user.phone || '')
      AppStorage.setOrCreate('currentUserNickname', user.nickname)
      AppStorage.setOrCreate('currentUserAvatar', user.avatar)

      // 持久化到 Preferences（包含所有关键信息）
      await PreferencesUtil.put('isLoggedIn', true)
      await PreferencesUtil.put('currentUserId', user.uid)
      await PreferencesUtil.put('currentUserEmail', user.email || '')
      await PreferencesUtil.put('currentUserPhone', user.phone || '')
      await PreferencesUtil.put('currentUserNickname', user.nickname)
      await PreferencesUtil.put('currentUserAvatar', user.avatar || '')

      // 保存最后登录的邮箱（无论是否勾选记住密码）
      if (user.email) {
        await this.saveLastLoginEmail(user.email)
      }

      console.info('[AuthViewModel] 登录状态已保存:', user.email || user.uid)
    } catch (err) {
      console.error('[AuthViewModel] 保存登录状态失败:', err)
    }
  }

  // 保存最后登录的邮箱（始终保存，与记住密码无关）
  async saveLastLoginEmail(email: string): Promise<void> {
    try {
      await PreferencesUtil.put('last_login_email', email)
    } catch (err) {
      console.error('[AuthViewModel] 保存邮箱失败:', err)
    }
  }

  // 获取最后登录的邮箱
  async getLastLoginEmail(): Promise<string> {
    try {
      const email = await PreferencesUtil.get<string>('last_login_email', '')
      return email || ''
    } catch (err) {
      return ''
    }
  }

  async logout(): Promise<void> {
    try {
      // AGConnect 退出登录（使用官方 API）
      try {
        await agconnect.auth().signOut()
      } catch (e) {
        // 忽略 AGConnect 退出错误（可能未登录）
      }

      AppStorage.setOrCreate('isLoggedIn', false)
      AppStorage.setOrCreate('currentUserId', '')
      AppStorage.setOrCreate('currentUserEmail', '')
      AppStorage.setOrCreate('currentUserPhone', '')
      AppStorage.setOrCreate('currentUserNickname', '')
      AppStorage.setOrCreate('currentUserAvatar', '')

      await PreferencesUtil.put('isLoggedIn', false)
      await PreferencesUtil.put('currentUserId', '')
      await PreferencesUtil.put('currentUserEmail', '')
      await PreferencesUtil.put('currentUserPhone', '')
      await PreferencesUtil.put('currentUserNickname', '')
      await PreferencesUtil.put('currentUserAvatar', '')
      // 注意：不清除 last_login_email，保留邮箱供下次登录
      console.info('[AuthViewModel] 已退出登录')
    } catch (err) {
      console.error('[AuthViewModel] 退出登录失败:', err)
    }
  }

  // "记住密码"功能 - 存储到本地 Preferences
  async saveRememberedUser(info: RememberedInfo): Promise<void> {
    try {
      await PreferencesUtil.put('remembered_email', info.email)
      await PreferencesUtil.put('remembered_password', info.password)
      await PreferencesUtil.put('remember_password', info.remember)
    } catch (err) {
      console.error('[AuthViewModel] 保存记住密码失败:', err)
    }
  }

  async getRememberedUser(): Promise<RememberedInfo | null> {
    try {
      const remember = await PreferencesUtil.get<boolean>('remember_password', false)
      if (!remember) {
        return null
      }

      const email = await PreferencesUtil.get<string>('remembered_email', '')
      const password = await PreferencesUtil.get<string>('remembered_password', '')

      if (email && password) {
        const result: RememberedInfo = { email, password, remember }
        return result
      }
      return null
    } catch (err) {
      console.error('[AuthViewModel] 获取记住密码失败:', err)
      return null
    }
  }

  async clearRememberedUser(): Promise<void> {
    try {
      await PreferencesUtil.delete('remembered_email')
      await PreferencesUtil.delete('remembered_password')
      await PreferencesUtil.put('remember_password', false)
    } catch (err) {
      console.error('[AuthViewModel] 清除记住密码失败:', err)
    }
  }

  // 启动时检查是否已登录，并恢复AppStorage状态
  async checkLoginState(): Promise<boolean> {
    try {
      const isLoggedIn = await PreferencesUtil.get<boolean>('isLoggedIn', false)
      if (isLoggedIn) {
        // 从Preferences恢复数据到AppStorage
        const userId = await PreferencesUtil.get<string>('currentUserId', '')
        const email = await PreferencesUtil.get<string>('currentUserEmail', '')
        const phone = await PreferencesUtil.get<string>('currentUserPhone', '')
        const nickname = await PreferencesUtil.get<string>('currentUserNickname', '')
        const avatar = await PreferencesUtil.get<string>('currentUserAvatar', '')

        AppStorage.setOrCreate('isLoggedIn', true)
        AppStorage.setOrCreate('currentUserId', userId)
        AppStorage.setOrCreate('currentUserEmail', email)
        AppStorage.setOrCreate('currentUserPhone', phone)
        AppStorage.setOrCreate('currentUserNickname', nickname)
        AppStorage.setOrCreate('currentUserAvatar', avatar)

        console.info('[AuthViewModel] 已恢复登录状态:', email || userId)
        return true
      }
      return false
    } catch (err) {
      console.error('[AuthViewModel] 检查登录状态失败:', err)
      return false
    }
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      const userId = await PreferencesUtil.get<string>('currentUserId', '')
      if (!userId || userId === '') {
        return null
      }
      return await this.cloudDBService.getUser(userId)
    } catch (err) {
      console.error('[AuthViewModel] 获取当前用户失败:', err)
      return null
    }
  }
}
