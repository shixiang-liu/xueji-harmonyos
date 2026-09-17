// 登录页面 - 支持密码登录和验证码登录双模式
// Swiss Spa 极简设计风格
import { promptAction, router } from '@kit.ArkUI'
import { AuthViewModel } from '../../../auth/viewmodel/AuthViewModel'
import window from '@ohos.window'
import { common } from '@kit.AbilityKit'
import { AuthInput, AuthButton, CodeInput, TextLink } from '../../../common/components/AuthComponents'
import { AppColors, AppSizes, AppAnimations, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { CloudDBService } from '../../../common/services/CloudDBService'
import agconnect from '@hw-agconnect/api-ohos'

@Entry
@Component
struct LoginPage {
  // 登录模式：0=密码登录, 1=验证码登录
  @State loginType: number = 0
  @State email: string = ''
  @State password: string = ''
  @State verificationCode: string = ''
  @State gestureHint: string = ''
  @State isLogoPressing: boolean = false
  @State clearStatus: string = '' // '' | 'clearing' | 'done' | 'error'
  @State clearMessage: string = ''
  @State logoTapCount: number = 0
  private logoTapTimer: number = -1
  @State rememberPassword: boolean = false
  @State isLoading: boolean = false
  @State isSendingCode: boolean = false
  @State countdown: number = 0
  @State pageOpacity: number = 0

  private viewModel: AuthViewModel = new AuthViewModel()

  private timerId: number = -1
  @State topSafeHeight: number = 0

  aboutToAppear() {
    this.initWindow()
    // 页面渐入动画
    setTimeout(() => {
      this.pageOpacity = 1
    }, 50)

    // 加载记住的密码和上次登录的邮箱
    this.loadRememberedData()
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private async initWindow() {
    try {
      const win = await window.getLastWindow(getContext(this))
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topSafeHeight = px2vp(avoidArea.topRect.height)
    } catch (e) {
      this.topSafeHeight = 0
    }
  }

  async loadRememberedData() {
    // 首先尝试获取记住的密码
    const savedInfo = await this.viewModel.getRememberedUser()
    if (savedInfo) {
      this.email = savedInfo.email
      this.password = savedInfo.password
      this.rememberPassword = savedInfo.remember
    } else {
      // 如果没有记住密码，至少回填上次登录的邮箱
      const lastEmail = await this.viewModel.getLastLoginEmail()
      if (lastEmail) {
        this.email = lastEmail
      }
    }
  }

  startCountdown() {
    this.countdown = 60
    this.timerId = setInterval(() => {
      if (this.countdown > 1) {
        this.countdown--
      } else {
        this.countdown = 0
        clearInterval(this.timerId)
        this.timerId = -1
      }
    }, 1000)
  }

  async handleSendCode() {
    if (!this.email.trim()) {
      promptAction.showToast({ message: '请输入邮箱' })
      return
    }

    this.isSendingCode = true
    const result = await this.viewModel.sendVerificationCode(this.email)
    this.isSendingCode = false

    if (result.success) {
      this.startCountdown()
    }
    promptAction.showToast({ message: result.message })
  }

  async checkGestureAvailability(): Promise<boolean> {
    if (!this.email.trim()) {
      this.gestureHint = ''
      return false
    }
    const hasGesture = await this.viewModel.hasGesture(this.email.trim())
    this.gestureHint = hasGesture ? '该账号已设置手势，可进入图案锁验证' : '该账号暂未设置手势，请先使用密码或验证码登录'
    return hasGesture
  }

  async handleLogin() {
    if (this.loginType === 0) {
      if (!this.email.trim() || !this.password.trim()) {
        promptAction.showToast({ message: '请输入邮箱和密码' })
        return
      }

      this.isLoading = true
      const result = await this.viewModel.loginWithPassword(this.email, this.password)
      this.isLoading = false

      if (result.success) {
        if (this.rememberPassword) {
          await this.viewModel.saveRememberedUser({
            email: this.email,
            password: this.password,
            remember: true
          })
        } else {
          await this.viewModel.clearRememberedUser()
        }

        promptAction.showToast({ message: '登录成功' })
        setTimeout(() => {
          router.replaceUrl({ url: 'diary/view/pages/HomePage' })
        }, 500)
      } else {
        promptAction.showToast({ message: result.message })
      }
      return
    }

    if (this.loginType === 1) {
      if (!this.email.trim() || !this.verificationCode.trim()) {
        promptAction.showToast({ message: '请输入邮箱和验证码' })
        return
      }

      this.isLoading = true
      const result = await this.viewModel.loginWithCode(this.email, this.verificationCode)
      this.isLoading = false

      if (result.success) {
        promptAction.showToast({ message: '登录成功' })
        setTimeout(() => {
          router.replaceUrl({ url: 'diary/view/pages/HomePage' })
        }, 500)
      } else {
        promptAction.showToast({ message: result.message })
      }
      return
    }

    const hasGesture = await this.checkGestureAvailability()
    if (!hasGesture) {
      promptAction.showToast({ message: '该账号未设置手势密码' })
      return
    }
    router.pushUrl({
      url: 'auth/view/pages/GesturePage',
      params: { mode: 'login', email: this.email.trim() }
    })
  }

  @Builder
  PasswordLoginForm() {
    Column() {
      AuthInput({
        label: '邮箱',
        placeholder: '请输入邮箱地址',
        text: $email
      })

      AuthInput({
        label: '密码',
        placeholder: '请输入密码',
        text: $password,
        inputType: InputType.Password
      })

      // 记住密码和忘记密码
      Row() {
        Row() {
          Checkbox()
            .select(this.rememberPassword)
            .selectedColor(AppColors.ACCENT)
            .width(18)
            .height(18)
            .onChange((value: boolean) => {
              this.rememberPassword = value
            })

          Text('记住密码')
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ left: AppSizes.SPACE_SM })
        }

        TextLink({
          text: '忘记密码？',
          action: () => {
            router.pushUrl({ url: 'auth/view/pages/ForgotPasswordPage' })
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: AppSizes.SPACE_3XL })
    }
    .width('100%')
  }

  @Builder
  CodeLoginForm() {
    Column() {
      AuthInput({
        label: '邮箱',
        placeholder: '请输入邮箱地址',
        text: $email
      })

      CodeInput({
        label: '验证码',
        placeholder: '请输入验证码',
        text: $verificationCode,
        countdown: this.countdown,
        isSending: this.isSendingCode,
        onSendCode: () => {
          this.handleSendCode()
        }
      })
    }
    .width('100%')
    .margin({ bottom: AppSizes.SPACE_2XL })
  }

  @Builder
  GestureLoginForm() {
    Column() {
      AuthInput({
        label: '邮箱',
        placeholder: '请输入邮箱地址',
        text: $email
      })

      if (this.gestureHint.length > 0) {
        Text(this.gestureHint)
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .margin({ bottom: AppSizes.SPACE_MD })
      }

      Text('点击登录后，在 3×3 图案锁面板中滑动完成验证')
        .fontSize(AppSizes.FONT_SM)
        .fontColor(AppColors.TEXT_TERTIARY)
        .width('100%')
    }
    .width('100%')
    .margin({ bottom: AppSizes.SPACE_2XL })
  }

  // Debug 入口：连点 logo 5 次清除全部数据
  private handleLogoTap(): void {
    // 短暂缩放反馈
    this.isLogoPressing = true
    setTimeout(() => { this.isLogoPressing = false }, 120)

    this.logoTapCount++

    if (this.logoTapTimer !== -1) {
      clearTimeout(this.logoTapTimer)
    }

    if (this.logoTapCount >= 5) {
      this.logoTapCount = 0
      this.confirmClearAllData()
      return
    }

    const remaining = 5 - this.logoTapCount
    this.clearStatus = 'clearing'
    this.clearMessage = `再点击 ${remaining} 次清除全部数据`
    this.logoTapTimer = setTimeout(() => {
      this.logoTapCount = 0
      this.clearStatus = ''
      this.clearMessage = ''
      this.logoTapTimer = -1
    }, 2500) as number
  }

  // Debug 入口：清除本地+云端所有数据
  private async confirmClearAllData(): Promise<void> {
    this.clearStatus = 'clearing'
    this.clearMessage = '步骤 1/4 正在清除云端数据...'
    let cloudCleared = false
    try {
      // 1. 先清云端（必须在 signOut 之前，否则丢失鉴权）
      try {
        await CloudDBService.getInstance().clearAllData()
        cloudCleared = true
      } catch (e) {
        console.warn('[LoginPage] 云端清除失败（继续清本地）:', JSON.stringify(e))
      }

      // 2. AGConnect 退出登录
      this.clearMessage = '步骤 2/4 正在退出登录...'
      try {
        await agconnect.auth().signOut()
      } catch (e) {
        console.warn('[LoginPage] AGConnect signOut 失败（可忽略）:', JSON.stringify(e))
      }

      // 3. 清本地 Preferences
      this.clearMessage = '步骤 3/4 正在清除本地存储...'
      await PreferencesUtil.clearAllData()

      // 4. 重置内存状态
      this.clearMessage = '步骤 4/4 正在重置应用状态...'
      AppStorage.setOrCreate('isLoggedIn', false)
      AppStorage.setOrCreate('currentUserId', '')
      AppStorage.setOrCreate('currentUserEmail', '')
      AppStorage.setOrCreate('currentUserPhone', '')
      AppStorage.setOrCreate('currentUserNickname', '')
      AppStorage.setOrCreate('currentUserAvatar', '')

      this.email = ''
      this.password = ''
      this.verificationCode = ''
      this.rememberPassword = false

      this.clearStatus = 'done'
      this.clearMessage = cloudCleared
        ? '已清除全部数据（含云端）'
        : '本地已清除，云端清除失败，请联网后再次清除'
    } catch (err) {
      console.error('[LoginPage] 清除数据失败:', err)
      this.clearStatus = 'error'
      this.clearMessage = '清除失败：' + (err as Error).message
    }
    setTimeout(() => {
      this.clearStatus = ''
      this.clearMessage = ''
    }, 4000)
  }

  build() {
    Stack() {
      // 顶部装饰渐变圆
      Column()
        .width(300)
        .height(300)
        .linearGradient(AppGradients.SPA_LAVENDER)
        .borderRadius(150)
        .position({ x: -100, y: -150 })
        .opacity(0.6)
      
      Column()
        .width(200)
        .height(200)
        .linearGradient(AppGradients.SPA_PEACH)
        .borderRadius(100)
        .position({ x: 250, y: -80 })
        .opacity(0.5)
      
      Scroll() {
        Column() {
          // 顶部留白 (适配状态栏)
          Blank().height(60 + this.topSafeHeight)

          // APP Logo + 名称
          Column() {
            Image($r('app.media.app_logo'))
              .width(88)
              .height(88)
              .objectFit(ImageFit.Contain)
            Text('学迹')
              .fontSize(AppSizes.FONT_LG)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: AppSizes.SPACE_SM })
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: AppSizes.SPACE_4XL })
          .scale(this.isLogoPressing ? { x: 0.95, y: 0.95 } : { x: 1, y: 1 })
          .animation({ duration: 120, curve: Curve.EaseInOut })
          .onClick(() => {
            this.handleLogoTap()
          })

      // 登录方式切换
      Row() {
        Text('密码登录')
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(this.loginType === 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.loginType === 0 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_TERTIARY)
          .padding({ bottom: AppSizes.SPACE_SM })
          .border({
            width: { bottom: this.loginType === 0 ? 2 : 0 },
            color: AppColors.TEXT_PRIMARY
          })
          .onClick(() => {
            this.loginType = 0
          })

        Text('验证码登录')
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(this.loginType === 1 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.loginType === 1 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_TERTIARY)
          .margin({ left: AppSizes.SPACE_3XL })
          .padding({ bottom: AppSizes.SPACE_SM })
          .border({
            width: { bottom: this.loginType === 1 ? 2 : 0 },
            color: AppColors.TEXT_PRIMARY
          })
          .onClick(() => {
            this.loginType = 1
          })

        Text('手势登录')
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(this.loginType === 2 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.loginType === 2 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_TERTIARY)
          .margin({ left: AppSizes.SPACE_3XL })
          .padding({ bottom: AppSizes.SPACE_SM })
          .border({
            width: { bottom: this.loginType === 2 ? 2 : 0 },
            color: AppColors.TEXT_PRIMARY
          })
          .onClick(async () => {
            this.loginType = 2
            await this.checkGestureAvailability()
          })
      }
      .width('100%')
      .margin({ bottom: AppSizes.SPACE_3XL })

      // 表单区域
      if (this.loginType === 0) {
        this.PasswordLoginForm()
      } else if (this.loginType === 1) {
        this.CodeLoginForm()
      } else {
        this.GestureLoginForm()
      }

      // 登录按钮
      AuthButton({
        label: this.loginType === 2 ? '绘制手势' : '登录',
        isLoading: this.isLoading,
        isEnabled: this.email.length > 0,
        action: () => {
          this.handleLogin()
        }
      })

      // 注册入口
      Row() {
        Text('还没有账户？')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_TERTIARY)

        Text('立即注册')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ left: AppSizes.SPACE_XS })
          .onClick(() => {
            router.pushUrl({ url: 'auth/view/pages/RegisterPage' })
          })
      }
      .margin({ top: AppSizes.SPACE_2XL })

      // 底部留白，确保滚动时内容不被遮挡
        Blank().height(60)
      }
      .width('100%')
      .padding({ left: AppSizes.SPACE_3XL, right: AppSizes.SPACE_3XL })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // Debug 状态横幅（最上层）
      if (this.clearStatus.length > 0) {
        Column() {
          Text(this.clearMessage)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .backgroundColor(this.clearStatus === 'error' ? '#E53935'
              : this.clearStatus === 'done' ? '#16A34A'
              : '#1F2937')
            .borderRadius(12)
        }
        .width('100%')
        .padding({ top: this.topSafeHeight + 20, left: 24, right: 24 })
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PRIMARY)
    .opacity(this.pageOpacity)
    .animation({ duration: AppAnimations.DURATION_SLOW, curve: Curve.EaseOut })
  }
}
