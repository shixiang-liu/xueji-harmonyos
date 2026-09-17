/**
 * @file AudioPlayer.ets
 * @description 音频播放工具类 - 基于 AudioRenderer 实现 PCM 格式音频播放
 */

import { audio } from '@kit.AudioKit'
import { fileIo as fs } from '@kit.CoreFileKit'

/**
 * 音频播放器
 * 支持播放、暂停、停止、跳转等操作
 */
export class AudioPlayer {
  /** 音频渲染器实例 */
  private audioRenderer: audio.AudioRenderer | null = null

  /** 播放状态标识 */
  private isPlaying: boolean = false

  /** 音频缓冲区大小 */
  private bufferSize: number = 0

  /** 字节率（16kHz * 16bit * 单声道） */
  private readonly BYTE_RATE = 32000

  /**
   * 初始化播放器
   * 配置与录音器相同的音频参数
   */
  async init(): Promise<void> {
    const options: audio.AudioRendererOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: {
        content: audio.ContentType.CONTENT_TYPE_SPEECH,
        usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
        rendererFlags: 0
      }
    }

    try {
      this.audioRenderer = await audio.createAudioRenderer(options)
      if (this.audioRenderer) {
        this.bufferSize = await this.audioRenderer.getBufferSize()
      }
    } catch (err) {
      console.error('[AudioPlayer] 初始化失败:', err)
    }
  }

  /**
   * 获取音频时长
   * @param audioPath 音频文件路径
   * @returns 时长（毫秒）
   */
  getDuration(audioPath: string): number {
    try {
      if (!fs.accessSync(audioPath)) return 0
      const stat = fs.statSync(audioPath)
      return Math.floor((stat.size / this.BYTE_RATE) * 1000)
    } catch (e) {
      return 0
    }
  }

  /**
   * 播放音频
   * @param audioPath 音频文件路径
   * @param seekTimeMs 跳转位置（毫秒）
   */
  async playAudio(audioPath: string, seekTimeMs: number = 0): Promise<void> {
    if (!this.audioRenderer) await this.init()
    if (!this.audioRenderer) return

    if (this.isPlaying) await this.stop()

    this.isPlaying = true

    try {
      await this.audioRenderer.start()

      const file = fs.openSync(audioPath, fs.OpenMode.READ_ONLY)

      // 跳转到指定位置
      if (seekTimeMs > 0) {
        const targetOffset = Math.floor((seekTimeMs / 1000) * this.BYTE_RATE)
        const stat = fs.statSync(audioPath)
        const safeOffset = Math.min(targetOffset, stat.size)

        let skipped = 0
        const tempBufSize = 4096
        const tempBuf = new ArrayBuffer(tempBufSize)

        while (skipped < safeOffset) {
          const remaining = safeOffset - skipped
          const toRead = Math.min(remaining, tempBufSize)
          const readLen = fs.readSync(file.fd, tempBuf, { length: toRead })
          if (readLen <= 0) break
          skipped += readLen
        }
      }

      let buffer = new ArrayBuffer(this.bufferSize)

      // 递归播放音频块
      const playChunk = async () => {
        if (!this.isPlaying || !this.audioRenderer) {
          fs.closeSync(file)
          if (this.audioRenderer && this.audioRenderer.state === audio.AudioState.STATE_RUNNING) {
            await this.audioRenderer.stop()
          }
          return
        }

        const bytesRead = fs.readSync(file.fd, buffer)
        if (bytesRead > 0) {
          if (this.audioRenderer.state === audio.AudioState.STATE_RUNNING) {
            await this.audioRenderer.write(buffer.slice(0, bytesRead))
            playChunk()
          }
        } else {
          // 播放完成
          if (this.audioRenderer.state === audio.AudioState.STATE_RUNNING) {
            await this.audioRenderer.drain()
          }
          await this.stop()
          fs.closeSync(file)
        }
      }

      playChunk()

    } catch (error) {
      this.isPlaying = false
    }
  }

  /**
   * 暂停播放
   */
  async pause(): Promise<void> {
    if (!this.audioRenderer || !this.isPlaying) return
    await this.audioRenderer.pause()
    this.isPlaying = false
  }

  /**
   * 停止播放
   */
  async stop(): Promise<void> {
    this.isPlaying = false
    if (this.audioRenderer && this.audioRenderer.state !== audio.AudioState.STATE_STOPPED) {
      await this.audioRenderer.stop()
    }
  }

  /**
   * 释放播放器资源
   */
  async release(): Promise<void> {
    if (!this.audioRenderer) return
    this.isPlaying = false
    await this.audioRenderer.release()
    this.audioRenderer = null
  }

  /**
   * 获取播放状态
   * @returns 是否正在播放
   */
  getIsPlaying(): boolean {
    return this.isPlaying
  }
}
