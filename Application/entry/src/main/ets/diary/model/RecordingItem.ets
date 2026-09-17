/**
 * @file RecordingItem.ets
 * @description 录音数据模型 - 定义单条录音的数据结构
 */

/**
 * 录音项数据模型
 * 用于存储单条录音的元数据和转写文本
 */
@Observed
export class RecordingItem {
  /** 录音唯一标识符 */
  id: string = ''

  /** 录音显示名称 */
  name: string = ''

  /** 录音文件存储路径 */
  audioPath: string = ''

  /** 录音时长（单位：秒） */
  audioDuration: number = 0

  /** 录音创建时间戳（毫秒） */
  createTime: number = 0

  /** 语音识别转写文本 */
  transcription: string = ''
}
