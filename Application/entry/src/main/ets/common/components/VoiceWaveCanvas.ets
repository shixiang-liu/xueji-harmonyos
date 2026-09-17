/**
 * @file VoiceWaveCanvas.ets
 * @description 录音声波动画组件 - 基于 Canvas 实现实时音量波纹效果
 * @features
 * - 接收音量参数，实时响应音量变化
 * - 多层波纹叠加效果
 * - 平滑动画过渡
 */

@Component
export struct VoiceWaveCanvas {
  /** 当前音量值 (0-100) */
  @Prop volume: number = 0;
  
  /** 是否正在录音 */
  @Prop @Watch('onRecordingStateChange') isRecording: boolean = false;
  
  /** Canvas 宽度 */
  @Prop canvasWidth: number = 200;
  
  /** Canvas 高度 */
  @Prop canvasHeight: number = 200;
  
  /** 主题色 */
  @Prop primaryColor: string = '#EF4444';
  
  /** Canvas 渲染上下文 */
  private canvasContext: CanvasRenderingContext2D | null = null;
  
  /** 动画定时器ID */
  private animationTimer: number = 0;
  
  /** Canvas 就绪状态 */
  private isCanvasReady: boolean = false;
  
  /** 波纹数据 */
  @State private waveRings: WaveRing[] = [];
  
  /** 柱状波形数据 */
  @State private barHeights: number[] = [];
  
  /** 目标柱状高度 */
  private targetBarHeights: number[] = [];
  
  /** 柱状数量 */
  private barCount: number = 32;
  
  /** 相位偏移 */
  private phase: number = 0;

  aboutToAppear() {
    // 初始化柱状波形数据
    this.barHeights = new Array(this.barCount).fill(0.1);
    this.targetBarHeights = new Array(this.barCount).fill(0.1);
  }

  aboutToDisappear() {
    this.stopAnimation();
  }
  
  /**
   * 监听录音状态变化
   */
  onRecordingStateChange() {
    if (!this.isCanvasReady) return;
    
    if (this.isRecording && this.animationTimer === 0) {
      this.startAnimation();
    } else if (!this.isRecording && this.animationTimer !== 0) {
      this.stopAnimation();
      // 清空画布
      if (this.canvasContext) {
        this.canvasContext.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
      }
    }
  }

  /**
   * Canvas 设置
   */
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);

  /**
   * 初始化 Canvas
   */
  private initCanvas(context: CanvasRenderingContext2D) {
    this.canvasContext = context;
    this.isCanvasReady = true;
    if (this.isRecording) {
      this.startAnimation();
    }
  }

  /**
   * 开始动画 - 使用 setInterval 代替 requestAnimationFrame
   */
  private startAnimation() {
    if (!this.canvasContext || this.animationTimer !== 0) return;
    
    // 约 60fps
    this.animationTimer = setInterval(() => {
      this.drawWave();
    }, 16);
  }

  /**
   * 停止动画
   */
  private stopAnimation() {
    if (this.animationTimer !== 0) {
      clearInterval(this.animationTimer);
      this.animationTimer = 0;
    }
  }

  /**
   * 绘制波形
   */
  private drawWave() {
    if (!this.canvasContext) return;
    
    const ctx = this.canvasContext;
    const width = this.canvasWidth;
    const height = this.canvasHeight;
    const centerX = width / 2;
    const centerY = height / 2;
    
    // 清空画布
    ctx.clearRect(0, 0, width, height);
    
    // 更新相位
    this.phase += 0.05;
    
    // 根据音量计算波形参数
    const normalizedVolume = Math.min(this.volume / 100, 1);
    const baseRadius = Math.min(width, height) * 0.15;
    
    // 绘制外层扩散波纹
    this.drawRipples(ctx, centerX, centerY, baseRadius, normalizedVolume);
    
    // 绘制中心圆形波形
    this.drawCenterWave(ctx, centerX, centerY, baseRadius, normalizedVolume);
    
    // 绘制环形柱状波形
    this.drawCircularBars(ctx, centerX, centerY, baseRadius, normalizedVolume);
  }

  /**
   * 绘制扩散波纹
   */
  private drawRipples(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    baseRadius: number,
    volume: number
  ) {
    const maxRipples = 4;
    const rippleSpeed = 2;
    
    // 根据音量添加新波纹
    if (volume > 0.1 && Math.random() < volume * 0.3) {
      if (this.waveRings.length < maxRipples) {
        this.waveRings.push({
          radius: baseRadius * 1.5,
          opacity: 0.6 + volume * 0.4,
          speed: rippleSpeed * (0.8 + volume * 0.4)
        });
      }
    }
    
    // 更新并绘制波纹
    const newRings: WaveRing[] = [];
    for (const ring of this.waveRings) {
      ring.radius += ring.speed;
      ring.opacity -= 0.015;
      
      if (ring.opacity > 0) {
        ctx.beginPath();
        ctx.arc(centerX, centerY, ring.radius, 0, Math.PI * 2);
        ctx.strokeStyle = this.hexToRgba(this.primaryColor, ring.opacity);
        ctx.lineWidth = 2;
        ctx.stroke();
        newRings.push(ring);
      }
    }
    this.waveRings = newRings;
  }

  /**
   * 绘制中心波形圆
   */
  private drawCenterWave(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    baseRadius: number,
    volume: number
  ) {
    const waveAmplitude = baseRadius * 0.3 * volume;
    const points = 64;
    
    // 绘制填充的波形圆
    ctx.beginPath();
    for (let i = 0; i <= points; i++) {
      const angle = (i / points) * Math.PI * 2;
      const waveOffset = Math.sin(angle * 6 + this.phase) * waveAmplitude +
                        Math.sin(angle * 4 - this.phase * 1.5) * waveAmplitude * 0.5;
      const radius = baseRadius + waveOffset;
      const x = centerX + Math.cos(angle) * radius;
      const y = centerY + Math.sin(angle) * radius;
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();
    
    // 渐变填充
    const gradient = ctx.createRadialGradient(
      centerX, centerY, 0,
      centerX, centerY, baseRadius * 1.5
    );
    gradient.addColorStop(0, this.hexToRgba(this.primaryColor, 0.8));
    gradient.addColorStop(0.7, this.hexToRgba(this.primaryColor, 0.4));
    gradient.addColorStop(1, this.hexToRgba(this.primaryColor, 0.1));
    
    ctx.fillStyle = gradient;
    ctx.fill();
    
    // 绘制边框
    ctx.strokeStyle = this.primaryColor;
    ctx.lineWidth = 2;
    ctx.stroke();
  }

  /**
   * 绘制环形柱状波形
   */
  private drawCircularBars(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    baseRadius: number,
    volume: number
  ) {
    const innerRadius = baseRadius * 1.6;
    const maxBarHeight = baseRadius * 0.8;
    const barWidth = 3;
    
    // 更新目标高度
    for (let i = 0; i < this.barCount; i++) {
      const angle = (i / this.barCount) * Math.PI * 2;
      const noise = Math.sin(angle * 3 + this.phase) * 0.3 +
                   Math.sin(angle * 7 - this.phase * 2) * 0.2;
      this.targetBarHeights[i] = 0.1 + volume * (0.5 + noise * 0.5);
    }
    
    // 平滑过渡
    for (let i = 0; i < this.barCount; i++) {
      this.barHeights[i] += (this.targetBarHeights[i] - this.barHeights[i]) * 0.15;
    }
    
    // 绘制柱状
    for (let i = 0; i < this.barCount; i++) {
      const angle = (i / this.barCount) * Math.PI * 2 - Math.PI / 2;
      const barHeight = this.barHeights[i] * maxBarHeight;
      
      const x1 = centerX + Math.cos(angle) * innerRadius;
      const y1 = centerY + Math.sin(angle) * innerRadius;
      const x2 = centerX + Math.cos(angle) * (innerRadius + barHeight);
      const y2 = centerY + Math.sin(angle) * (innerRadius + barHeight);
      
      // 渐变色
      const gradient = ctx.createLinearGradient(x1, y1, x2, y2);
      gradient.addColorStop(0, this.hexToRgba(this.primaryColor, 0.6));
      gradient.addColorStop(1, this.hexToRgba(this.primaryColor, 1));
      
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.strokeStyle = gradient;
      ctx.lineWidth = barWidth;
      ctx.lineCap = 'round';
      ctx.stroke();
    }
  }

  /**
   * 十六进制颜色转 RGBA
   */
  private hexToRgba(hex: string, alpha: number): string {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    if (result) {
      const r = parseInt(result[1], 16);
      const g = parseInt(result[2], 16);
      const b = parseInt(result[3], 16);
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    }
    return `rgba(239, 68, 68, ${alpha})`;
  }

  build() {
    Canvas(this.canvasContext)
      .width(this.canvasWidth)
      .height(this.canvasHeight)
      .onReady(() => {
        this.canvasContext = new CanvasRenderingContext2D(this.canvasSettings);
        this.initCanvas(this.canvasContext);
        // 如果组件就绪时已经在录音，启动动画
        if (this.isRecording) {
          this.startAnimation();
        }
      })
  }
}

/**
 * 波纹数据接口
 */
interface WaveRing {
  radius: number;
  opacity: number;
  speed: number;
}

/**
 * 简化版声波组件 - 水平柱状波形
 * 适用于小空间显示
 */
@Component
export struct VoiceWaveBars {
  /** 当前音量值 (0-100) */
  @Prop volume: number = 0;
  
  /** 是否正在录音 */
  @Prop isRecording: boolean = false;
  
  /** 柱状数量 */
  @Prop barCount: number = 5;
  
  /** 主题色 */
  @Prop primaryColor: string = '#EF4444';
  
  /** 柱状高度数据 */
  @State barHeights: number[] = [];
  
  /** 动画定时器 */
  private animationTimer: number = 0;

  aboutToAppear() {
    this.barHeights = new Array(this.barCount).fill(0.2);
    this.startAnimation();
  }

  aboutToDisappear() {
    this.stopAnimation();
  }

  private startAnimation() {
    this.animationTimer = setInterval(() => {
      if (this.isRecording) {
        const normalizedVolume = Math.min(this.volume / 100, 1);
        this.barHeights = this.barHeights.map((_, index) => {
          const phase = Date.now() / 200 + index * 0.5;
          const noise = Math.sin(phase) * 0.3 + Math.sin(phase * 2.3) * 0.2;
          return 0.2 + normalizedVolume * (0.6 + noise * 0.4);
        });
      } else {
        this.barHeights = this.barHeights.map(h => h * 0.9 + 0.2 * 0.1);
      }
    }, 50);
  }

  private stopAnimation() {
    if (this.animationTimer) {
      clearInterval(this.animationTimer);
      this.animationTimer = 0;
    }
  }

  build() {
    Row({ space: 3 }) {
      ForEach(this.barHeights, (height: number, index: number) => {
        Column()
          .width(4)
          .height(`${height * 100}%`)
          .backgroundColor(this.primaryColor)
          .borderRadius(2)
          .animation({
            duration: 100,
            curve: Curve.EaseInOut
          })
      })
    }
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }
}
