// ============================================================================
// 注册页面 - RegisterPage
// ============================================================================
// 功能：邮箱 + 验证码注册，设置密码和昵称
// 风格：Swiss Spa 极简设计
// ============================================================================

import { promptAction, router } from '@kit.ArkUI'
import { AuthViewModel, ValidationResult } from '../../../auth/viewmodel/AuthViewModel'
import { AuthInput, AuthButton, CodeInput, TextLink } from '../../../common/components/AuthComponents'
import { AppColors, AppSizes, AppAnimations, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { BackIconButton } from '../../../common/components/BackIconButton'
import { AVATAR_PRESETS } from '../../../common/services/AvatarStore'
import window from '@ohos.window'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct RegisterPage {
  // 表单数据
  @State email: string = ''
  @State verificationCode: string = ''
  @State @Watch('onPasswordChange') password: string = ''
  @State confirmPassword: string = ''
  @State nickname: string = ''
  // 状态
  @State isLoading: boolean = false
  @State isSendingCode: boolean = false
  @State countdown: number = 0
  @State currentStep: number = 1 // 1=邮箱验证, 2=设置密码
  @State pageOpacity: number = 0
  @State agreeTerms: boolean = false
  // 密码强度 0-3
  @State passwordStrength: number = 0
  // 预设头像索引（0-5），默认选第 0 个
  @State selectedAvatar: number = 0
  private viewModel: AuthViewModel = new AuthViewModel()
  private timerId: number = -1
  @State topSafeHeight: number = 0

  aboutToAppear() {
    this.initWindow()
    // 页面渐入动画
    setTimeout(() => {
      this.pageOpacity = 1
    }, 50)
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

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  // 开始验证码倒计时
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

  // 发送验证码
  async handleSendCode() {
    if (!this.email.trim()) {
      promptAction.showToast({ message: '请输入邮箱' })
      return
    }

    this.isSendingCode = true
    const result = await this.viewModel.sendCodeForRegister(this.email)
    this.isSendingCode = false

    if (result.success) {
      this.startCountdown()
    }
    promptAction.showToast({ message: result.message })
  }

  // 验证邮箱，进入下一步
  async handleVerifyEmail() {
    if (!this.email.trim()) {
      promptAction.showToast({ message: '请输入邮箱' })
      return
    }
    if (!this.verificationCode.trim()) {
      promptAction.showToast({ message: '请输入验证码' })
      return
    }

    // 验证码格式检查
    if (this.verificationCode.length !== 6) {
      promptAction.showToast({ message: '请输入6位验证码' })
      return
    }

    // 验证验证码是否有效（通过AGConnect验证）
    this.isLoading = true
    const verifyResult = await this.viewModel.verifyEmailCode(this.email, this.verificationCode)
    this.isLoading = false

    if (!verifyResult.success) {
      promptAction.showToast({ message: verifyResult.message })
      return
    }

    // 验证成功，进入设置密码步骤
    promptAction.showToast({ message: '验证成功' })
    this.currentStep = 2
  }

  // 提交注册
  async handleRegister() {
    // 验证密码
    const passwordCheck = this.viewModel.validatePassword(this.password)
    if (!passwordCheck.valid) {
      promptAction.showToast({ message: passwordCheck.message })
      return
    }

    // 确认密码
    if (this.password !== this.confirmPassword) {
      promptAction.showToast({ message: '两次密码输入不一致' })
      return
    }

    // 协议同意
    if (!this.agreeTerms) {
      promptAction.showToast({ message: '请阅读并同意服务协议' })
      return
    }

    this.isLoading = true
    const result = await this.viewModel.register({
      email: this.email,
      password: this.password,
      code: this.verificationCode,
      nickname: this.nickname || `用户${this.email.split('@')[0].slice(-4)}`,
      avatar: `preset:${this.selectedAvatar}`
    })
    this.isLoading = false

    if (result.success) {
      // 注册成功后自动登录，直接跳转到主页
      promptAction.showToast({ message: '注册成功' })
      setTimeout(() => {
        router.replaceUrl({
          url: 'auth/view/pages/GesturePage',
          params: { mode: 'setup', email: this.email.trim() }
        })
      }, 500)
    } else {
      promptAction.showToast({ message: result.message })
    }
  }

  // 密码强度计算 - 通过 @Watch 监听 password 变化
  onPasswordChange() {
    this.passwordStrength = this.viewModel.calculatePasswordStrength(this.password)
  }

  // 获取密码强度文案
  getStrengthText(): string {
    const texts: string[] = ['', '弱', '中', '强']
    return texts[this.passwordStrength] || ''
  }

  // 获取密码强度颜色
  getStrengthColor(): string {
    const colors: string[] = [AppColors.TEXT_HINT, AppColors.ERROR, AppColors.WARNING, AppColors.SUCCESS]
    return colors[this.passwordStrength] || AppColors.TEXT_HINT
  }

  @Builder
  StepIndicator() {
    Row() {
      // 步骤1
      Column() {
        Text('1')
          .fontSize(14)
          .fontColor(this.currentStep >= 1 ? Color.White : AppColors.TEXT_HINT)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.currentStep >= 1 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
          .borderRadius(14)

        Text('验证邮箱')
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.currentStep >= 1 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_HINT)
          .margin({ top: AppSizes.SPACE_XS })
      }
      .alignItems(HorizontalAlign.Center)

      // 连接线
      Divider()
        .width(60)
        .height(2)
        .color(this.currentStep >= 2 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
        .margin({ left: AppSizes.SPACE_SM, right: AppSizes.SPACE_SM })

      // 步骤2
      Column() {
        Text('2')
          .fontSize(14)
          .fontColor(this.currentStep >= 2 ? Color.White : AppColors.TEXT_HINT)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.currentStep >= 2 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
          .borderRadius(14)

        Text('设置密码')
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.currentStep >= 2 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_HINT)
          .margin({ top: AppSizes.SPACE_XS })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ bottom: AppSizes.SPACE_3XL })
  }

  @Builder
  EmailVerifyForm() {
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

      AuthButton({
        label: '下一步',
        isLoading: false,
        isEnabled: this.email.length > 0 && this.verificationCode.length === 6,
        action: () => {
          this.handleVerifyEmail()
        }
      })
    }
    .width('100%')
  }

  @Builder
  AvatarChip(index: number) {
    Stack() {
      Image(AVATAR_PRESETS[index])
        .width(52)
        .height(52)
        .borderRadius(26)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#f5f0e8')
        .border(this.selectedAvatar === index
          ? { width: 3, color: AppColors.ACCENT }
          : { width: 0, color: 'transparent' })

      if (this.selectedAvatar === index) {
        Column() {
          Text('✓')
            .fontSize(12)
            .fontColor('#ffffff')
            .fontWeight(FontWeight.Bold)
        }
        .width(18)
        .height(18)
        .borderRadius(9)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.ACCENT)
        .border({ width: 2, color: '#ffffff' })
        .position({ x: 37, y: 37 })
      }
    }
    .width(56)
    .height(56)
    .onClick(() => {
      this.selectedAvatar = index
    })
  }

  @Builder
  SetPasswordForm() {
    Column() {
      // 昵称（可选）
      AuthInput({
        label: '昵称（可选）',
        placeholder: '给自己取个名字吧',
        text: $nickname
      })

      // 选头像
      Column({ space: 10 }) {
        Row() {
          Text('选个头像')
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_SECONDARY)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          Text('后续可在"我的"里更换')
            .fontSize(AppSizes.FONT_XS)
            .fontColor(AppColors.TEXT_HINT)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          this.AvatarChip(0)
          this.AvatarChip(1)
          this.AvatarChip(2)
          this.AvatarChip(3)
          this.AvatarChip(4)
          this.AvatarChip(5)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .padding({ top: AppSizes.SPACE_MD, bottom: AppSizes.SPACE_SM })
      .alignItems(HorizontalAlign.Start)

      // 密码
      AuthInput({
        label: '设置密码',
        placeholder: '8-26位，包含字母和数字',
        text: $password,
        inputType: InputType.Password
      })

      // 密码强度指示器
      if (this.password.length > 0) {
        Row() {
          Text('密码强度：')
            .fontSize(AppSizes.FONT_XS)
            .fontColor(AppColors.TEXT_TERTIARY)

          Text(this.getStrengthText())
            .fontSize(AppSizes.FONT_XS)
            .fontColor(this.getStrengthColor())
            .fontWeight(FontWeight.Medium)

          Row() {
            ForEach([1, 2, 3], (level: number) => {
              Rect()
                .width(20)
                .height(4)
                .fill(this.passwordStrength >= level ? this.getStrengthColor() : AppColors.BG_TERTIARY)
                .borderRadius(2)
                .margin({ left: 4 })
            })
          }
          .margin({ left: AppSizes.SPACE_SM })
        }
        .width('100%')
        .margin({ top: -AppSizes.SPACE_MD, bottom: AppSizes.SPACE_LG })
      }

      // 确认密码
      AuthInput({
        label: '确认密码',
        placeholder: '请再次输入密码',
        text: $confirmPassword,
        inputType: InputType.Password
      })

      // 服务协议
      Row() {
        Checkbox()
          .select(this.agreeTerms)
          .selectedColor(AppColors.ACCENT)
          .width(18)
          .height(18)
          .onChange((value: boolean) => {
            this.agreeTerms = value
          })

        Text('我已阅读并同意')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ left: AppSizes.SPACE_SM })

        Text('《服务协议》')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.ACCENT)
          .onClick(() => {
            // TODO: 跳转协议页面
          })

        Text('和')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)

        Text('《隐私政策》')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.ACCENT)
          .onClick(() => {
            // TODO: 跳转隐私政策页面
          })
      }
      .width('100%')
      .margin({ top: AppSizes.SPACE_LG, bottom: AppSizes.SPACE_3XL })

      // 注册按钮
      AuthButton({
        label: '完成注册',
        isLoading: this.isLoading,
        isEnabled: this.password.length >= 8 && this.confirmPassword.length >= 8 && this.agreeTerms,
        action: () => {
          this.handleRegister()
        }
      })

      // 返回上一步
      TextLink({
        text: '返回上一步',
        action: () => {
          this.currentStep = 1
        }
      })
        .margin({ top: AppSizes.SPACE_LG })
    }
    .width('100%')
  }

  build() {
    Stack() {
      // 问题1修复：背景装饰层 - 设置hitTestBehavior避免被动画影响
      // 背景层独立于主容器的opacity动画
      Column() {
        // 问题1修复：顶部装饰渐变圆 - 增加偏移确保在状态栏下方完全可见
        Column()
          .width(250)
          .height(250)
          .linearGradient(AppGradients.SPA_MINT)
          .borderRadius(125)
          .position({ x: -80, y: this.topSafeHeight + 20 })  // 增加偏移，显示更多圆
          .opacity(0.7)

        Column()
          .width(180)
          .height(180)
          .linearGradient(AppGradients.SPA_SKY)
          .borderRadius(90)
          .position({ x: 260, y: this.topSafeHeight + 50 })  // 更向下显示
          .opacity(0.6)

        // 底部装饰圆 - 增强视觉层次
        Column()
          .width(200)
          .height(200)
          .linearGradient(AppGradients.SWISS_MINIMAL)
          .borderRadius(100)
          .position({ x: -60, y: '70%' })
          .opacity(0.5)

        Column()
          .width(150)
          .height(150)
          .linearGradient(AppGradients.SPA_MINT)
          .borderRadius(75)
          .position({ x: '75%', y: '80%' })
          .opacity(0.5)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)  // 不拦截触摸事件
      .backgroundColor(AppColors.BG_PRIMARY)  // 背景色放在装饰层

      Column() {
        // 顶部返回按钮（固定）
        Row() {
          BackIconButton({
            onBack: () => {
              router.back()
            }
          })

          Blank()
        }
        .width('100%')
        .height(56 + this.topSafeHeight)
        .padding({ left: AppSizes.SPACE_3XL, right: AppSizes.SPACE_3XL, top: this.topSafeHeight })

        // 可滚动内容区域
        Scroll() {
          Column() {
            // 标题区域
            Column() {
              Text('创建账户')
                .fontSize(AppSizes.FONT_3XL)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .margin({ bottom: AppSizes.SPACE_SM })

              Text('开始你的学习之旅')
                .fontSize(AppSizes.FONT_MD)
                .fontColor(AppColors.TEXT_TERTIARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: AppSizes.SPACE_3XL })

            // 步骤指示器
            this.StepIndicator()

            // 表单区域
            if (this.currentStep === 1) {
              this.EmailVerifyForm()
            } else {
              this.SetPasswordForm()
            }

            // 已有账户
            Row() {
              Text('已有账户？')
                .fontSize(AppSizes.FONT_SM)
                .fontColor(AppColors.TEXT_TERTIARY)

              Text('立即登录')
                .fontSize(AppSizes.FONT_SM)
                .fontColor(AppColors.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
                .margin({ left: AppSizes.SPACE_XS })
                .onClick(() => {
                  router.back()
                })
            }
            .margin({ top: AppSizes.SPACE_2XL, bottom: AppSizes.SPACE_5XL })

            // 底部垫片，防遮挡
            Blank()
              .height(50)
          }
          .width('100%')
          .padding({
            left: AppSizes.SPACE_3XL,
            right: AppSizes.SPACE_3XL,
            top: 80 + this.topSafeHeight,
            bottom: AppSizes.SPACE_XL
          }) // 内容内边距
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .scrollBarColor(AppColors.TEXT_HINT)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top) // 顶部对齐
      }
      .width('100%')
      .height('100%')
      // 移除外层 Padding，使滚动条贴边
      .backgroundColor(AppColors.BG_PRIMARY)
      .opacity(this.pageOpacity)
      .animation({ duration: AppAnimations.DURATION_SLOW, curve: Curve.EaseOut })
    }
  }
}
