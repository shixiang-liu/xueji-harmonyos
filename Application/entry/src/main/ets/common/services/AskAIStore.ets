import { common } from '@kit.AbilityKit'
import { LongCatService } from './LongCatService'
import { PreferencesUtil } from '../utils/PreferencesUtil'
import { NoteItem } from '../../diary/model/NoteItem'

/**
 * 单条对话消息
 */
@Observed
export class AskAIMessage {
  role: string = ''
  content: string = ''

  constructor(role: string = '', content: string = '') {
    this.role = role
    this.content = content
  }
}

/**
 * 一次对话会话（含历史消息）
 */
@Observed
export class AskAISession {
  id: string = ''
  title: string = '新对话'
  createdAt: number = 0
  updatedAt: number = 0
  messages: AskAIMessage[] = []

  constructor(id: string = '', title: string = '新对话') {
    this.id = id
    this.title = title
    this.createdAt = Date.now()
    this.updatedAt = Date.now()
    this.messages = []
  }
}

/**
 * AskAIStore：跨页面共享的"随时问"状态
 * - sessions[0] 是当前活跃会话
 * - sessions[1..n] 是历史会话（按 updatedAt 倒序）
 * - 持久化：sessions 数组通过 PreferencesUtil 存到磁盘，跨重启保留
 * - UI 状态（visible/loading/error/input/fabXY）继续走 AppStorage（进程内）
 */
export class AskAIStore {
  static readonly KEY_VISIBLE = 'askAI_visible'
  static readonly KEY_INPUT = 'askAI_input'
  static readonly KEY_LOADING = 'askAI_loading'
  static readonly KEY_ERROR = 'askAI_error'
  static readonly KEY_FAB_X = 'askAI_fabX'
  static readonly KEY_FAB_Y = 'askAI_fabY'
  static readonly KEY_SESSIONS = 'askAI_sessions'         // AppStorage 数组
  static readonly KEY_SHOW_HISTORY = 'askAI_show_history' // sheet 内是否切到历史视图
  static readonly PERSIST_KEY = 'askai_sessions_v1'       // PreferencesUtil 持久化键
  static readonly MAX_SESSIONS = 30                        // 上限，超出删最老的

  static readonly WELCOME = '你可以问学习记录里的内容，也可以直接问学习方法、复习计划或某个知识点。'

  /** 应用启动时调一次：初始化 AppStorage 默认值 + 从磁盘加载历史会话 */
  static initIfNeeded(context?: common.Context): void {
    if (AppStorage.get<boolean>(AskAIStore.KEY_VISIBLE) === undefined) {
      AppStorage.setOrCreate<boolean>(AskAIStore.KEY_VISIBLE, false)
    }
    if (AppStorage.get<string>(AskAIStore.KEY_INPUT) === undefined) {
      AppStorage.setOrCreate<string>(AskAIStore.KEY_INPUT, '')
    }
    if (AppStorage.get<boolean>(AskAIStore.KEY_LOADING) === undefined) {
      AppStorage.setOrCreate<boolean>(AskAIStore.KEY_LOADING, false)
    }
    if (AppStorage.get<string>(AskAIStore.KEY_ERROR) === undefined) {
      AppStorage.setOrCreate<string>(AskAIStore.KEY_ERROR, '')
    }
    if (AppStorage.get<number>(AskAIStore.KEY_FAB_X) === undefined) {
      AppStorage.setOrCreate<number>(AskAIStore.KEY_FAB_X, 0)
    }
    if (AppStorage.get<number>(AskAIStore.KEY_FAB_Y) === undefined) {
      AppStorage.setOrCreate<number>(AskAIStore.KEY_FAB_Y, 0)
    }
    if (AppStorage.get<boolean>(AskAIStore.KEY_SHOW_HISTORY) === undefined) {
      AppStorage.setOrCreate<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
    }
    if (AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) === undefined) {
      AppStorage.setOrCreate<AskAISession[]>(AskAIStore.KEY_SESSIONS, [AskAIStore.makeNewSession()])
    }
  }

  /** 应用启动时主动调用，从持久化恢复历史会话 */
  static async loadFromDisk(context: common.Context): Promise<void> {
    AskAIStore.initIfNeeded()
    try {
      const raw = await PreferencesUtil.get(AskAIStore.PERSIST_KEY, '') as string
      if (!raw) return
      const sessions = JSON.parse(raw) as AskAISession[]
      if (Array.isArray(sessions) && sessions.length > 0) {
        // 反序列化后消息也要重新实例化（确保 @Observed 行为正常）
        const restored = sessions.map((s: AskAISession) => {
          const session = new AskAISession(s.id, s.title || '新对话')
          session.createdAt = s.createdAt || Date.now()
          session.updatedAt = s.updatedAt || s.createdAt || Date.now()
          session.messages = (s.messages || []).map(
            (m: AskAIMessage) => new AskAIMessage(m.role, m.content)
          )
          return session
        })
        AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, restored)
        console.info(`[AskAIStore] 加载历史会话 ${restored.length} 个`)
      }
    } catch (e) {
      console.warn('[AskAIStore] 加载历史会话失败:', e)
    }
  }

  /** 写盘 */
  private static async persist(): Promise<void> {
    try {
      const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
      await PreferencesUtil.put(AskAIStore.PERSIST_KEY, JSON.stringify(sessions))
    } catch (e) {
      console.warn('[AskAIStore] 持久化失败:', e)
    }
  }

  private static makeNewSession(): AskAISession {
    const session = new AskAISession(
      `s_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      '新对话'
    )
    session.messages = [new AskAIMessage('assistant', AskAIStore.WELCOME)]
    return session
  }

  /** 当前活跃会话 = sessions[0] */
  static getActive(): AskAISession {
    AskAIStore.initIfNeeded()
    const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
    if (sessions.length === 0) {
      const fresh = AskAIStore.makeNewSession()
      AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, [fresh])
      return fresh
    }
    return sessions[0]
  }

  /** 打开抽屉（不重置会话） */
  static open(): void {
    AskAIStore.initIfNeeded()
    AppStorage.set<string>(AskAIStore.KEY_ERROR, '')
    AppStorage.set<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
    AppStorage.set<boolean>(AskAIStore.KEY_VISIBLE, true)
  }

  static close(): void {
    AppStorage.set<boolean>(AskAIStore.KEY_VISIBLE, false)
    AppStorage.set<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
  }

  /** 开新对话：当前会话归档到历史，新建一个空 session 作为 active */
  static newSession(): void {
    AskAIStore.initIfNeeded()
    const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
    const fresh = AskAIStore.makeNewSession()
    // 把当前 active 留作历史（如果非空对话，即用户实际问过）
    const active = sessions.length > 0 ? sessions[0] : null
    let next: AskAISession[]
    if (active && active.messages.some((m: AskAIMessage) => m.role === 'user')) {
      next = [fresh, active, ...sessions.slice(1)]
    } else {
      // 当前会话还没真正用过，直接替换
      next = [fresh, ...sessions.slice(1)]
    }
    if (next.length > AskAIStore.MAX_SESSIONS) {
      next = next.slice(0, AskAIStore.MAX_SESSIONS)
    }
    AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, next)
    AppStorage.set<string>(AskAIStore.KEY_INPUT, '')
    AppStorage.set<string>(AskAIStore.KEY_ERROR, '')
    AppStorage.set<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
    AskAIStore.persist()
  }

  /** 切到历史里的某个会话作为当前 active */
  static activateSession(id: string): void {
    const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
    const idx = sessions.findIndex((s: AskAISession) => s.id === id)
    if (idx <= 0) {
      AppStorage.set<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
      return
    }
    const target = sessions[idx]
    const others = sessions.filter((_: AskAISession, i: number) => i !== idx)
    AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, [target, ...others])
    AppStorage.set<boolean>(AskAIStore.KEY_SHOW_HISTORY, false)
    AskAIStore.persist()
  }

  /** 删除某个历史会话 */
  static deleteSession(id: string): void {
    const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
    const next = sessions.filter((s: AskAISession) => s.id !== id)
    if (next.length === 0) {
      next.push(AskAIStore.makeNewSession())
    }
    AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, next)
    AskAIStore.persist()
  }

  /** 发送一条消息（写入当前 active 会话） */
  static async send(context: common.Context): Promise<void> {
    const question = (AppStorage.get<string>(AskAIStore.KEY_INPUT) || '').trim()
    if (question.length === 0) return
    if (AppStorage.get<boolean>(AskAIStore.KEY_LOADING)) return

    AppStorage.set<boolean>(AskAIStore.KEY_LOADING, true)
    AppStorage.set<string>(AskAIStore.KEY_ERROR, '')

    const sessions = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
    if (sessions.length === 0) sessions.push(AskAIStore.makeNewSession())
    const active = sessions[0]
    const userMsg = new AskAIMessage('user', question)
    active.messages = [...active.messages, userMsg]
    active.updatedAt = Date.now()
    if (active.title === '新对话') {
      active.title = AskAIStore.deriveTitle(question)
    }
    AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS, [active, ...sessions.slice(1)])
    AppStorage.set<string>(AskAIStore.KEY_INPUT, '')

    try {
      const allNotes = await PreferencesUtil.loadNotes(context)
      const recentNotes = allNotes.slice(0, 30)
      const notesContext = recentNotes.map((n: NoteItem) => {
        const title = (n.title || '无标题').substring(0, 40)
        const content = (n.content || '').replace(/\n/g, ' ').substring(0, 200)
        const date = n.date || ''
        return `- ${date} | ${title}: ${content}`
      }).join('\n')

      const conversation = active.messages
        .slice(-10)
        .map((m: AskAIMessage) => `${m.role === 'user' ? '用户' : 'AI'}：${m.content}`)
        .join('\n')

      const systemPrompt = `你是一个面向学生的多轮学习助手，不只是检索学习记录。
规则：
1. 如果用户问的是记录里的内容，优先结合下面最近学习记录回答，并用「《标题》」标注来源。
2. 如果记录里没有答案，可以用通用学习方法、课程常识和推理继续帮用户，但要说明"记录中没有直接依据"。
3. 保持多轮上下文，回答简洁、可执行，不要把自己限制成单轮问答。

用户的最近学习记录：
${notesContext || '（暂无记录）'}`

      const answer = await LongCatService.getInstance().chat(conversation, systemPrompt, false)
      const sessionsNow = AppStorage.get<AskAISession[]>(AskAIStore.KEY_SESSIONS) || []
      const activeNow = sessionsNow.length > 0 ? sessionsNow[0] : active
      if (answer && answer.length > 0) {
        activeNow.messages = [...activeNow.messages, new AskAIMessage('assistant', answer)]
        activeNow.updatedAt = Date.now()
        AppStorage.set<AskAISession[]>(AskAIStore.KEY_SESSIONS,
          [activeNow, ...sessionsNow.slice(1)])
      } else {
        AppStorage.set<string>(AskAIStore.KEY_ERROR, 'AI 暂时无法回答，请检查网络或稍后重试')
      }
    } catch (e) {
      AppStorage.set<string>(AskAIStore.KEY_ERROR, '请求失败：' + (e as Error).message)
    }

    AppStorage.set<boolean>(AskAIStore.KEY_LOADING, false)
    AskAIStore.persist()
  }

  /** 用首句生成会话标题：取前 14 个字 */
  private static deriveTitle(firstUserMessage: string): string {
    const cleaned = firstUserMessage.replace(/\s+/g, ' ').trim()
    if (cleaned.length === 0) return '新对话'
    return cleaned.length > 14 ? cleaned.substring(0, 14) + '…' : cleaned
  }
}
