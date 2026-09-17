import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 音频播放器组件
 * 用于播放白噪音和音效
 */
export class AudioPlayer {
  private static instance: AudioPlayer;
  private whiteNoisePlayer: media.AVPlayer | null = null;
  private soundPlayer: media.AVPlayer | null = null;
  private isWhiteNoisePlaying: boolean = false;
  private currentWhiteNoiseType: string = 'none';

  private constructor() {
  }

  public static getInstance(): AudioPlayer {
    if (!AudioPlayer.instance) {
      AudioPlayer.instance = new AudioPlayer();
    }
    return AudioPlayer.instance;
  }

  /**
   * 播放白噪音
   * @param type 白噪音类型：'rain', 'ocean', 'forest', 'none'
   * @param context 上下文，用于获取资源路径
   */
  public async playWhiteNoise(type: string, context: Context): Promise<void> {
    if (type === 'none') {
      this.stopWhiteNoise();
      return;
    }

    // 如果已经在播放相同类型的白噪音，不重复播放
    if (this.isWhiteNoisePlaying && this.currentWhiteNoiseType === type) {
      return;
    }

    // 停止当前播放
    this.stopWhiteNoise();

    try {
      // 问题3修复：获取音频文件名
      const fileName = this.getWhiteNoiseFileName(type)
      if (!fileName) {
        console.warn(`[AudioPlayer] White noise resource not found: ${type}`)
        return
      }
      
      // 问题3修复：使用resourceManager获取rawfile的文件描述符
      // 注意：音频文件需要放在resources/rawfile/目录下
      const resourceManager = context.resourceManager
      const rawFd = await resourceManager.getRawFd(fileName)
      
      // 创建播放器
      this.whiteNoisePlayer = await media.createAVPlayer()
      
      // 问题3修复：使用fdSrc而不是url来播放资源文件
      this.whiteNoisePlayer.fdSrc = {
        fd: rawFd.fd,
        offset: rawFd.offset,
        length: rawFd.length
      }
      this.whiteNoisePlayer.loop = true // 循环播放
      
      // 监听状态变化和错误
      this.whiteNoisePlayer.on('stateChange', async (state: string) => {
        console.info(`[AudioPlayer] White noise state changed: ${state}`)
        if (state === 'error') {
          console.error('[AudioPlayer] White noise playback error')
          await this.stopWhiteNoise()
        }
      })
      
      await this.whiteNoisePlayer.prepare()
      await this.whiteNoisePlayer.setVolume(0.3)
      await this.whiteNoisePlayer.play()
      
      this.isWhiteNoisePlaying = true
      this.currentWhiteNoiseType = type
      console.info(`[AudioPlayer] White noise started: ${type} (${fileName})`)
    } catch (err) {
      const error = err as BusinessError
      console.error(`[AudioPlayer] Play white noise failed. Code: ${error.code}, Message: ${error.message}`)
      // 防止闪退：静默失败，清理状态
      this.isWhiteNoisePlaying = false
      this.currentWhiteNoiseType = 'none'
      if (this.whiteNoisePlayer) {
        try { await this.whiteNoisePlayer.release() } catch (e) {}
        this.whiteNoisePlayer = null
      }
    }
  }

  /**
   * 停止白噪音
   */
  public async stopWhiteNoise(): Promise<void> {
    if (this.whiteNoisePlayer) {
      try {
        await this.whiteNoisePlayer.pause();
        await this.whiteNoisePlayer.release();
        this.whiteNoisePlayer = null;
        this.isWhiteNoisePlaying = false;
        this.currentWhiteNoiseType = 'none';
        console.info('[AudioPlayer] White noise stopped');
      } catch (err) {
        const error = err as BusinessError;
        console.error(`[AudioPlayer] Stop white noise failed. Code: ${error.code}, Message: ${error.message}`);
      }
    }
  }

  /**
   * 播放音效
   * @param soundType 音效类型：'start', 'end', 'tick'
   * @param context 上下文
   */
  public async playSound(soundType: string, context: Context): Promise<void> {
    try {
      // 如果已有音效在播放，先停止
      if (this.soundPlayer) {
        await this.soundPlayer.release();
        this.soundPlayer = null;
      }

      this.soundPlayer = await media.createAVPlayer();
      const soundPath = this.getSoundPath(soundType, context);
      
      if (soundPath) {
        this.soundPlayer.url = soundPath;
        this.soundPlayer.loop = false;
        
        await this.soundPlayer.prepare();
        await this.soundPlayer.setVolume(0.7);
        await this.soundPlayer.play();
        
        // 播放完成后释放资源
        this.soundPlayer.on('stateChange', async (state: string) => {
          if (state === 'completed' || state === 'stopped') {
            if (this.soundPlayer) {
              await this.soundPlayer.release();
              this.soundPlayer = null;
            }
          }
        });
        
        console.info(`[AudioPlayer] Sound played: ${soundType}`);
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[AudioPlayer] Play sound failed. Code: ${error.code}, Message: ${error.message}`);
    }
  }

  /**
   * 获取白噪音文件名
   * 问题3修复：文件需要放在resources/rawfile/目录下
   * 支持的文件: forest.wav, rain.wav, SeaWaves.wav
   */
  private getWhiteNoiseFileName(type: string): string | null {
    switch (type) {
      case 'rain':
        return 'rain.wav'
      case 'ocean':
        return 'SeaWaves.wav'
      case 'forest':
        return 'forest.wav'
      default:
        console.warn(`[AudioPlayer] Unsupported white noise type: ${type}`)
        return null
    }
  }

  /**
   * 获取音效路径
   */
  private getSoundPath(soundType: string, context: Context): string | null {
    try {
      // 文件路径：resources/rawfile/sounds/{soundType}.mp3
      return `rawfile://sounds/${soundType}.mp3`;
    } catch (err) {
      console.error(`[AudioPlayer] Get sound path failed: ${JSON.stringify(err)}`);
      return null;
    }
  }

  /**
   * 释放所有资源
   */
  public async release(): Promise<void> {
    await this.stopWhiteNoise();
    if (this.soundPlayer) {
      try {
        await this.soundPlayer.release();
        this.soundPlayer = null;
      } catch (err) {
        console.error(`[AudioPlayer] Release sound player failed: ${JSON.stringify(err)}`);
      }
    }
  }

  /**
   * 检查是否正在播放白噪音
   */
  public isPlaying(): boolean {
    return this.isWhiteNoisePlaying;
  }

  /**
   * 获取当前白噪音类型
   */
  public getCurrentWhiteNoiseType(): string {
    return this.currentWhiteNoiseType;
  }
}

