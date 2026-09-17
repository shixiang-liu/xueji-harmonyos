// ============================================================================
// 忘记密码页面 - ForgotPasswordPage
// ============================================================================
// 功能：通过邮箱 + 验证码重置密码
// 风格：Swiss Spa 极简设计
// ============================================================================

import { promptAction, router } from '@kit.ArkUI'
import { AuthViewModel } from '../../../auth/viewmodel/AuthViewModel'
import { AuthInput, AuthButton, CodeInput } from '../../../common/components/AuthComponents'
import { AppColors, AppSizes, AppAnimations, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { BackIconButton } from '../../../common/components/BackIconButton'
import window from '@ohos.window'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct ForgotPasswordPage {
  // 表单数据
  @State email: string = ''
  @State verificationCode: string = ''
  @State @Watch('onPasswordChange') newPassword: string = ''
  @State confirmPassword: string = ''

  // 状态
  @State isLoading: boolean = false
  @State isSendingCode: boolean = false
  @State countdown: number = 0
  @State currentStep: number = 1 // 1=验证邮箱, 2=设置新密码
  @State pageOpacity: number = 0

  // 密码强度 0-3
  @State passwordStrength: number = 0

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
    const normalizedEmail = this.email.trim().toLowerCase()
    if (!normalizedEmail) {
      promptAction.showToast({ message: '请输入邮箱' })
      return
    }

    this.email = normalizedEmail
    this.isSendingCode = true
    const result = await this.viewModel.sendCodeForReset(normalizedEmail)
    this.isSendingCode = false

    if (result.success) {
      this.startCountdown()
    }
    promptAction.showToast({ message: result.message })
  }

  // 验证邮箱，进入下一步
  async handleVerifyEmail() {
    const normalizedEmail = this.email.trim().toLowerCase()
    const normalizedCode = this.verificationCode.trim()
    if (!normalizedEmail) {
      promptAction.showToast({ message: '请输入邮箱' })
      return
    }
    if (!normalizedCode) {
      promptAction.showToast({ message: '请输入验证码' })
      return
    }

    // 验证码格式检查
    if (normalizedCode.length !== 6) {
      promptAction.showToast({ message: '请输入6位验证码' })
      return
    }

    this.email = normalizedEmail
    this.verificationCode = normalizedCode
    this.isLoading = true
    const verifyResult = await this.viewModel.verifyEmailCode(normalizedEmail, normalizedCode)
    this.isLoading = false
    if (!verifyResult.success) {
      promptAction.showToast({ message: verifyResult.message })
      return
    }

    // 验证成功后进入设置新密码步骤
    promptAction.showToast({ message: '验证成功' })
    this.currentStep = 2
  }

  // 重置密码
  async handleResetPassword() {
    // 验证密码
    const passwordCheck = this.viewModel.validatePassword(this.newPassword)
    if (!passwordCheck.valid) {
      promptAction.showToast({ message: passwordCheck.message })
      return
    }

    // 确认密码
    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({ message: '两次密码输入不一致' })
      return
    }

    this.isLoading = true
    const result = await this.viewModel.resetPassword(
      this.email.trim().toLowerCase(),
      this.verificationCode.trim(),
      this.newPassword
    )
    this.isLoading = false

    if (result.success) {
      promptAction.showToast({ message: '密码重置成功，请重新登录' })
      setTimeout(() => {
        router.back()
      }, 1000)
    } else {
      promptAction.showToast({ message: result.message })
    }
  }

  // 密码强度计算 - 通过 @Watch 监听 newPassword 变化
  onPasswordChange() {
    this.passwordStrength = this.viewModel.calculatePasswordStrength(this.newPassword)
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
  EmailVerifyForm() {
    Column() {
      // 提示文字
      Text('请输入注册时使用的邮箱，我们将发送验证码帮助您重置密码')
        .fontSize(AppSizes.FONT_SM)
        .fontColor(AppColors.TEXT_TERTIARY)
        .width('100%')
        .margin({ bottom: AppSizes.SPACE_2XL })

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
        isLoading: this.isLoading,
        isEnabled: this.email.trim().length > 0 && this.verificationCode.trim().length === 6,
        action: () => {
          this.handleVerifyEmail()
        }
      })
    }
    .width('100%')
  }

  @Builder
  SetPasswordForm() {
    Column() {
      // 新密码
      AuthInput({
        label: '新密码',
        placeholder: '8-26位，包含字母和数字',
        text: $newPassword,
        inputType: InputType.Password
      })

      // 密码强度指示器
      if (this.newPassword.length > 0) {
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
        label: '确认新密码',
        placeholder: '请再次输入新密码',
        text: $confirmPassword,
        inputType: InputType.Password
      })

      // 重置按钮
      AuthButton({
        label: '重置密码',
        isLoading: this.isLoading,
        isEnabled: this.newPassword.length >= 8 && this.confirmPassword.length >= 8,
        action: () => {
          this.handleResetPassword()
        }
      })
        .margin({ top: AppSizes.SPACE_LG })

      // 返回上一步
      Button('返回上一步')
        .width('100%')
        .height(48)
        .fontSize(AppSizes.FONT_MD)
        .fontColor(AppColors.TEXT_SECONDARY)
        .backgroundColor(Color.Transparent)
        .margin({ top: AppSizes.SPACE_MD })
        .onClick(() => {
          this.currentStep = 1
        })
    }
    .width('100%')
  }

  build() {
    Stack() {
      // 顶部装饰渐变圆
      Column()
        .width(220)
        .height(220)
        .linearGradient(AppGradients.SPA_ROSE)
        .borderRadius(110)
        .position({ x: -60, y: -100 })
        .opacity(0.5)
      
      Column()
        .width(160)
        .height(160)
        .linearGradient(AppGradients.SPA_PEACH)
        .borderRadius(80)
        .position({ x: 260, y: -40 })
        .opacity(0.4)
        
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
            Text('重置密码')
              .fontSize(AppSizes.FONT_3XL)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
              .margin({ bottom: AppSizes.SPACE_SM })
            Text(this.currentStep === 1 ? '验证邮箱地址' : '设置新密码')
              .fontSize(AppSizes.FONT_MD)
              .fontColor(AppColors.TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: AppSizes.SPACE_3XL })

          // 步骤指示器
          Row() {
            // 步骤1
            Row() {
              Text('1')
                .fontSize(12)
                .fontColor(this.currentStep >= 1 ? Color.White : AppColors.TEXT_HINT)
                .width(24)
                .height(24)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.currentStep >= 1 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
                .borderRadius(12)

              Text('验证邮箱')
                .fontSize(AppSizes.FONT_XS)
                .fontColor(this.currentStep >= 1 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_HINT)
                .margin({ left: AppSizes.SPACE_XS })
            }

            // 连接线
            Divider()
              .width(40)
              .height(2)
              .color(this.currentStep >= 2 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
              .margin({ left: AppSizes.SPACE_SM, right: AppSizes.SPACE_SM })

            // 步骤2
            Row() {
              Text('2')
                .fontSize(12)
                .fontColor(this.currentStep >= 2 ? Color.White : AppColors.TEXT_HINT)
                .width(24)
                .height(24)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.currentStep >= 2 ? AppColors.ACCENT : AppColors.BG_TERTIARY)
                .borderRadius(12)

              Text('设置密码')
                .fontSize(AppSizes.FONT_XS)
                .fontColor(this.currentStep >= 2 ? AppColors.TEXT_PRIMARY : AppColors.TEXT_HINT)
                .margin({ left: AppSizes.SPACE_XS })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: AppSizes.SPACE_3XL })

          // 表单区域
          if (this.currentStep === 1) {
            this.EmailVerifyForm()
          } else {
            this.SetPasswordForm()
          }

          // 返回登录
          Row() {
            Text('想起密码了？')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_TERTIARY)

            Text('返回登录')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_PRIMARY)
              .fontWeight(FontWeight.Medium)
              .margin({ left: AppSizes.SPACE_XS })
              .onClick(() => {
                router.back()
              })
          }
          .margin({ top: AppSizes.SPACE_2XL, bottom: AppSizes.SPACE_5XL })
        }
        .width('100%')
        }
        .width('100%')
        .padding({ left: AppSizes.SPACE_3XL, right: AppSizes.SPACE_3XL })
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .scrollBarColor(AppColors.TEXT_HINT)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.End)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 80 + this.topSafeHeight, bottom: AppSizes.SPACE_XL })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PRIMARY)
    .opacity(this.pageOpacity)
    .animation({ duration: AppAnimations.DURATION_SLOW, curve: Curve.EaseOut })
  }
}
