/**
 * @file AudioRecorder.ets
 * @description 音频录制工具类 - 基于 AudioCapturer 实现 PCM 格式录音
 */

import { audio } from '@kit.AudioKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

/**
 * 音频录制器
 * 支持实时音频采集、文件保存及回调处理
 */
export class AudioRecorder {
  /** 音频采集器实例 */
  private audioCapturer: audio.AudioCapturer | null = null

  /** 当前录音文件路径 */
  private audioPath: string = ''

  /** 录音状态标识 */
  private isRecording: boolean = false

  /** 音频数据回调（用于语音识别等场景） */
  private onDataCallback: ((buffer: ArrayBuffer) => void) | null = null

  /** 音量回调（用于声波动画） */
  private onVolumeCallback: ((volume: number) => void) | null = null

  /** 文件句柄 */
  private fileHandle: fs.File | null = null

  /**
   * 初始化录音器
   * 配置采样率16kHz、单声道、16位采样
   */
  async init(): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    }

    try {
      this.audioCapturer = await audio.createAudioCapturer(options)
    } catch (error) {
      console.error('[AudioRecorder] 初始化失败:', error)
    }
  }

  /**
   * 开始录音
   * @param onDataCallback 音频数据回调函数（可选）
   * @param onVolumeCallback 音量回调函数（可选，0-100）
   * @returns 录音文件路径
   */
  async startRecording(
    onDataCallback?: (buffer: ArrayBuffer) => void,
    onVolumeCallback?: (volume: number) => void
  ): Promise<string> {
    if (!this.audioCapturer) {
      console.error('[AudioRecorder] 录音器未初始化')
      return ''
    }
    if (this.isRecording) {
      console.error('[AudioRecorder] 正在录音中')
      return ''
    }

    this.audioPath = this.generateAudioPath()
    this.onDataCallback = onDataCallback || null
    this.onVolumeCallback = onVolumeCallback || null

    try {
      this.fileHandle = fs.openSync(this.audioPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE)
      await this.audioCapturer.start()
      this.isRecording = true
      this.startContinuousRead()
      return this.audioPath
    } catch (error) {
      this.isRecording = false
      if (this.fileHandle) {
        fs.closeSync(this.fileHandle)
        this.fileHandle = null
      }
      console.error('[AudioRecorder] 启动录音失败:', error)
      return ''
    }
  }

  /**
   * 持续读取音频数据
   * @private
   */
  private async startContinuousRead(): Promise<void> {
    if (!this.audioCapturer) return

    const bufferSize = await this.audioCapturer.getBufferSize()

    while (this.isRecording) {
      try {
        const buffer = await this.audioCapturer.read(bufferSize, true)
        if (buffer && buffer.byteLength > 0) {
          // 写入文件
          if (this.fileHandle) {
            fs.writeSync(this.fileHandle.fd, buffer)
          }
          // 回调处理（如语音识别）
          if (this.onDataCallback) {
            this.onDataCallback(buffer)
          }
          // 计算音量并回调
          if (this.onVolumeCallback) {
            const volume = this.calculateVolume(buffer)
            this.onVolumeCallback(volume)
          }
        }
      } catch (error) {
        if (this.isRecording) {
          console.error('[AudioRecorder] 读取音频数据失败:', error)
        }
      }
    }
  }

  /**
   * 停止录音
   * @returns 录音文件路径
   */
  async stopRecording(): Promise<string> {
    if (!this.audioCapturer || !this.isRecording) {
      return this.audioPath
    }

    this.isRecording = false

    // 等待读取循环结束
    await new Promise<void>((resolve) => setTimeout(resolve, 100))

    try {
      if (this.audioCapturer.state === audio.AudioState.STATE_RUNNING) {
        await this.audioCapturer.stop()
      }
    } catch (error) {
      console.error('[AudioRecorder] 停止录音失败:', error)
    } finally {
      if (this.fileHandle) {
        fs.closeSync(this.fileHandle)
        this.fileHandle = null
      }
      this.onDataCallback = null
      this.onVolumeCallback = null
    }

    return this.audioPath
  }

  /**
   * 计算音频缓冲区的音量 (RMS)
   * @param buffer 音频数据
   * @returns 音量值 0-100
   */
  private calculateVolume(buffer: ArrayBuffer): number {
    const int16Array = new Int16Array(buffer)
    let sum = 0
    
    for (let i = 0; i < int16Array.length; i++) {
      sum += int16Array[i] * int16Array[i]
    }
    
    // 计算 RMS (均方根)
    const rms = Math.sqrt(sum / int16Array.length)
    
    // 将 RMS 转换为 0-100 的范围
    // 16位音频最大值为 32768
    const normalizedVolume = Math.min(100, (rms / 32768) * 300)
    
    return normalizedVolume
  }

  /**
   * 生成音频文件路径
   * @private
   * @returns 文件路径
   */
  private generateAudioPath(): string {
    const context = getContext() as common.UIAbilityContext
    return `${context.filesDir}/audio_${Date.now()}.wav`
  }

  /**
   * 释放录音器资源
   */
  async release(): Promise<void> {
    if (this.audioCapturer) {
      this.isRecording = false
      if (this.audioCapturer.state !== audio.AudioState.STATE_RELEASED) {
        await this.audioCapturer.release()
      }
      this.audioCapturer = null
    }
    if (this.fileHandle) {
      fs.closeSync(this.fileHandle)
      this.fileHandle = null
    }
  }

  /**
   * 删除音频文件
   * @param audioPath 文件路径
   */
  static async deleteAudioFile(audioPath: string): Promise<void> {
    try {
      await fs.unlink(audioPath)
    } catch (error) {
      console.error('[AudioRecorder] 删除文件失败:', error)
    }
  }
}
