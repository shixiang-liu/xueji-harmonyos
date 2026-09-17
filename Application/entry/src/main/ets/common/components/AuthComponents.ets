// 认证相关UI组件 - Creamy UI Refactor
// 风格：Soft, Clean, Friendly
import { AppColors, AppSizes, AppShadows, AppAnimations, AppGradients, LinearGradient } from '../utils/AppTheme'

// 极简输入框组件 - Creamy Style
// 使用 @Link 双向绑定避免输入时重新渲染
@Component
export struct AuthInput {
  @Prop label: string = ''
  @Prop placeholder: string = ''
  @Link text: string
  @State isFocused: boolean = false
  inputType: InputType = InputType.Normal

  build() {
    Column() {
      if (this.label) {
        Text(this.label)
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: AppSizes.SPACE_SM })
          .width('100%')
      }

      TextInput({ placeholder: this.placeholder, text: $$this.text })
        .type(this.inputType)
        .width('100%')
        .height(56)
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius(AppSizes.RADIUS_LG)
        .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG })
        .fontSize(AppSizes.FONT_MD)
        .fontColor(AppColors.TEXT_PRIMARY)
        .placeholderColor(AppColors.TEXT_HINT)
        .shadow(this.isFocused ? AppShadows.SHADOW_SM : undefined)
        .border({
          width: 1,
          color: this.isFocused ? AppColors.ACCENT : 'transparent'
        })
        .onFocus(() => {
          this.isFocused = true
        })
        .onBlur(() => {
          this.isFocused = false
        })
    }
    .width('100%')
    .margin({ bottom: AppSizes.SPACE_LG })
  }
}

// 主按钮组件 - Creamy Pill
@Component
export struct AuthButton {
  @Prop label: string = ''
  @Prop isLoading: boolean = false
  @Prop isEnabled: boolean = true
  @State isPressed: boolean = false
  action: () => void = () => {}

  build() {
    Button({ type: ButtonType.Normal }) {
      if (this.isLoading) {
        LoadingProgress()
          .color(Color.White)
          .width(24)
          .height(24)
      } else {
        Text(this.label)
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .letterSpacing(1)
      }
    }
    .width('100%')
    .height(56)
    // .backgroundColor(this.isEnabled ? AppColors.ACCENT : AppColors.TEXT_DISABLED) // Old Flat Color
    .linearGradient(this.isEnabled ? AppGradients.PRIMARY_BTN : { angle: 0, colors: [[AppColors.TEXT_DISABLED, 0], [AppColors.TEXT_DISABLED, 1]] }) // Gradient
    .borderRadius(28) // Pill shape
    .shadow(this.isEnabled ? AppShadows.SHADOW_MD : undefined)
    .enabled(this.isEnabled && !this.isLoading)
    .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
    .animation(AppAnimations.SPRING_BOUNCE)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
      }
    })
    .onClick(() => {
      if (this.isEnabled && !this.isLoading) {
        this.action()
      }
    })
  }
}

// 次要按钮组件
@Component
export struct SecondaryButton {
  @Prop label: string = ''
  @Prop isLoading: boolean = false
  @State isPressed: boolean = false
  action: () => void = () => {}

  build() {
    Button({ type: ButtonType.Normal }) {
      if (this.isLoading) {
        LoadingProgress()
          .color(AppColors.TEXT_PRIMARY)
          .width(20)
          .height(20)
      } else {
        Text(this.label)
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor(Color.Transparent)
    .border({ width: 1, color: AppColors.BORDER })
    .borderRadius(24)
    .enabled(!this.isLoading)
    .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
    .animation(AppAnimations.SPRING_BOUNCE)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
      }
    })
    .onClick(() => {
      if (!this.isLoading) {
        this.action()
      }
    })
  }
}

// 验证码输入组件
@Component
export struct CodeInput {
  @Prop label: string = ''
  @Prop placeholder: string = ''
  @Link text: string
  @Prop countdown: number = 0
  @Prop isSending: boolean = false
  @State isFocused: boolean = false
  onSendCode: () => void = () => {}

  build() {
    Column() {
      if (this.label) {
        Text(this.label)
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: AppSizes.SPACE_SM })
          .width('100%')
      }

      Row() {
        TextInput({ placeholder: this.placeholder, text: $$this.text })
          .layoutWeight(1)
          .height(56)
          .backgroundColor(AppColors.BG_SECONDARY)
          .borderRadius(AppSizes.RADIUS_LG)
          .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG })
          .fontSize(AppSizes.FONT_MD)
          .fontColor(AppColors.TEXT_PRIMARY)
          .placeholderColor(AppColors.TEXT_HINT)
          .shadow(this.isFocused ? AppShadows.SHADOW_SM : undefined)
          .border({
            width: 1,
            color: this.isFocused ? AppColors.ACCENT : 'transparent'
          })
          .onFocus(() => {
            this.isFocused = true
          })
          .onBlur(() => {
            this.isFocused = false
          })

        Button({ type: ButtonType.Normal }) {
          if (this.isSending) {
            LoadingProgress()
              .color(Color.White)
              .width(20)
              .height(20)
          } else {
            Text(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width(110)
        .height(56)
        .margin({ left: AppSizes.SPACE_MD })
        .backgroundColor(this.countdown > 0 ? AppColors.TEXT_DISABLED : AppColors.ACCENT)
        .borderRadius(28)
        .shadow(this.countdown > 0 ? undefined : AppShadows.SHADOW_SM)
        .enabled(this.countdown === 0 && !this.isSending)
        .onClick(() => {
          this.onSendCode()
        })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: AppSizes.SPACE_LG })
  }
}

// 密码强度指示器
@Component
export struct PasswordStrengthBar {
  @Prop strength: number = 0  // 0-3

  private getColor(level: number): ResourceColor {
    if (level > this.strength) return AppColors.BG_TERTIARY
    if (this.strength === 1) return AppColors.ERROR
    if (this.strength === 2) return AppColors.WARNING
    return AppColors.SUCCESS
  }

  private getLabel(): string {
    if (this.strength === 0) return ''
    if (this.strength === 1) return '弱'
    if (this.strength === 2) return '中'
    return '强'
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        ForEach([1, 2, 3], (level: number) => {
          Column()
            .layoutWeight(1)
            .height(4)
            .backgroundColor(this.getColor(level))
            .borderRadius(2)
            .animation(AppAnimations.SPRING_NORMAL)
        })
      }
      .width('100%')

      if (this.strength > 0) {
        Text(`密码强度：${this.getLabel()}`)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.getColor(this.strength))
          .margin({ top: AppSizes.SPACE_XS })
          .width('100%')
          .animation(AppAnimations.SPRING_NORMAL)
      }
    }
    .width('100%')
    .margin({ top: AppSizes.SPACE_SM })
  }
}

// 文本链接组件
@Component
export struct TextLink {
  @Prop text: string = ''
  action: () => void = () => {}

  build() {
    Text(this.text)
      .fontSize(AppSizes.FONT_SM)
      .fontColor(AppColors.ACCENT)
      .fontWeight(FontWeight.Medium)
      .onClick(() => {
        this.action()
      })
  }
}
