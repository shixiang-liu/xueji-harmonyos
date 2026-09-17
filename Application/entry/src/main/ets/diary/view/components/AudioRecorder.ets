
import { AppColors } from '../../../common/utils/AppTheme'

/** 波纹数据接口 - 用于圆形水波纹扩散动画 */
interface RippleData {
  radius: number // 当前半径
  opacity: number // 当前透明度
  speed: number // 扩散速度
  lineWidth: number // 线条粗细
}

@Simple
@Component
export struct AudioRecorder {
  @Link isRecording: boolean
  @Link isProcessing: boolean
  @Link recordingSeconds: number
  @Prop currentVolume: number // 0-100

  // 事件回调
  onStartRecording: () => void = () => {}
  onStopRecording: () => void = () => {}

  // Canvas 绘图上下文
  private waveCanvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private waveCanvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.waveCanvasSettings)
  
  // 波纹动画状态
  private ripples: Array<RippleData> = []
  private rippleAnimationTimer: number = 0
  private lastRippleTime: number = 0
  
  aboutToDisappear() {
    this.stopRippleAnimation()
  }

  build() {
    Row({ space: 16 }) {
      // 录音按钮区域 - Canvas 波纹 + 按钮叠加（固定尺寸，不扩大）
      Stack() {
        // ========== Canvas 水波纹动画（录音时显示，在按钮后面） ==========
        if (this.isRecording) {
          Canvas(this.waveCanvasContext)
            .width(120)
            .height(120)
            .backgroundColor(Color.Transparent)
            .onReady(() => {
              this.startRippleAnimation()
            })
        }

        // 主按钮（始终居中）
        Column() {
          if (this.isProcessing) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(AppColors.TEXT_WHITE)
          } else if (this.isRecording) {
            Column()
              .width(14)
              .height(14)
              .borderRadius(2)
              .backgroundColor('#FFFFFF')
          } else {
            Column() {
              Column()
                .width(12)
                .height(16)
                .borderRadius(6)
                .backgroundColor(AppColors.TEXT_WHITE)
              Column()
                .width(18)
                .height(10)
                .borderRadius({
                  topLeft: 0,
                  topRight: 0,
                  bottomLeft: 9,
                  bottomRight: 9
                })
                .backgroundColor(Color.Transparent)
                .border({ width: 2, color: AppColors.TEXT_WHITE })
                .margin({ top: -6 })
              Column()
                .width(2)
                .height(4)
                .backgroundColor(AppColors.TEXT_WHITE)
              Column()
                .width(12)
                .height(2)
                .borderRadius(1)
                .backgroundColor(AppColors.TEXT_WHITE)
            }
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width(52)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(26)
        .backgroundColor(this.isRecording ? '#DC2626' : '#292524')
        .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)', offsetY: 4 })
      }
      .width(120) // 固定尺寸，容纳波纹但不会变化
      .height(120)
      .clip(true) // 裁剪超出部分
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          if (!this.isRecording && !this.isProcessing) {
            this.onStartRecording()
          }
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          if (this.isRecording) {
            this.onStopRecording()
          }
        }
      })

      // 状态文字
      Column({ space: 4 }) {
        Text(this.isRecording ? this.formatDuration(this.recordingSeconds) : '长按录音')
          .fontSize(15)
          .fontWeight(this.isRecording ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.isRecording ? AppColors.RECORDING : AppColors.TEXT_PRIMARY)
          .letterSpacing(0.3)

        if (this.isRecording) {
          Text('松开结束')
            .fontSize(12)
            .fontColor(AppColors.TEXT_HINT)
        } else if (!this.isProcessing) {
          Text('语音转文字自动识别')
            .fontSize(12)
            .fontColor(AppColors.TEXT_HINT)
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 24,
      top: 8,
      bottom: 8
    })
    .justifyContent(FlexAlign.Start)
    .backgroundColor(AppColors.BG_SECONDARY)
    .border({ width: { top: 0.5 }, color: AppColors.BORDER_LIGHT })
    .shadow({
      radius: 12,
      color: '#0000000A',
      offsetX: 0,
      offsetY: -4
    })
  }

  /**
   * 启动波纹动画循环
   */
  private startRippleAnimation(): void {
    if (this.rippleAnimationTimer) {
      clearInterval(this.rippleAnimationTimer)
    }
    this.ripples = []

    // 60fps 动画循环
    this.rippleAnimationTimer = setInterval(() => {
      if (this.isRecording) {
        this.updateRipples()
        this.drawRipples()
      }
    }, 16)
  }

  /**
   * 停止波纹动画
   */
  private stopRippleAnimation(): void {
    if (this.rippleAnimationTimer) {
      clearInterval(this.rippleAnimationTimer)
      this.rippleAnimationTimer = 0
    }
    this.ripples = []
  }

  /**
   * 更新波纹状态 - 核心动画逻辑
   */
  private updateRipples(): void {
    const now = Date.now()
    const centerRadius = 26 // 按钮半径
    const maxRadius = 58 // 最大扩散半径
    const volume = this.currentVolume

    // ===== 根据音量生成新波纹 =====
    if (volume > 3) {
      // 音量越大，波纹生成越频繁（间隔 60ms ~ 200ms）
      const interval = Math.max(60, 200 - volume * 1.4)

      if (now - this.lastRippleTime > interval) {
        // 波纹初始线宽与音量相关（1.5 ~ 4）
        const lineWidth = 1.5 + (volume / 100) * 2.5
        // 波纹扩散速度与音量相关（0.6 ~ 1.8）
        const speed = 0.6 + (volume / 100) * 1.2

        this.ripples.push({
          radius: centerRadius + 2,
          opacity: 0.7 + (volume / 100) * 0.3, // 初始透明度 0.7 ~ 1.0
          speed: speed,
          lineWidth: lineWidth
        })
        this.lastRippleTime = now
      }
    }

    // ===== 更新所有波纹 =====
    for (let i = this.ripples.length - 1; i >= 0; i--) {
      const ripple = this.ripples[i]
      
      // 半径增加
      ripple.radius += ripple.speed
      
      // 透明度衰减 (半径接近最大时衰减更快)
      if (ripple.radius > maxRadius * 0.8) {
        ripple.opacity -= 0.05
      } else {
        ripple.opacity -= 0.015
      }

      // 移除消失的波纹
      if (ripple.opacity <= 0 || ripple.radius > maxRadius) {
        this.ripples.splice(i, 1)
      }
    }
  }

  /**
   * 绘制所有波纹
   */
  private drawRipples(): void {
    const ctx = this.waveCanvasContext
    const width = 120
    const height = 120
    const centerX = width / 2
    const centerY = height / 2

    // 清空画布
    ctx.clearRect(0, 0, width, height)

    // 绘制每个波纹
    this.ripples.forEach(ripple => {
      ctx.beginPath()
      ctx.arc(centerX, centerY, ripple.radius, 0, 6.28) // 2*PI approx 6.28
      
      // 颜色：基于音量的热烈程度 (红色/橙色)
      // 使用 rgba 字符串
      ctx.strokeStyle = `rgba(220, 38, 38, ${Math.max(0, ripple.opacity)})` // Red-600
      
      ctx.lineWidth = ripple.lineWidth
      ctx.stroke()
    })
  }

  /** 格式化时长 (秒 -> mm:ss) */
  private formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }
}
