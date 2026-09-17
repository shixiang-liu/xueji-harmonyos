export class GestureAuthUtil {
  static isValidGesture(gesture: string): boolean {
    if (!gesture) {
      return false
    }

    const steps = gesture.split('-')
    if (steps.length < 4) {
      return false
    }

    const seen: Set<string> = new Set()
    for (let index = 0; index < steps.length; index++) {
      const step = steps[index]
      const value = Number(step)
      if (!Number.isInteger(value) || value < 1 || value > 9 || seen.has(step)) {
        return false
      }
      seen.add(step)
    }
    return true
  }

  static hashGesture(gesture: string): string {
    let hash = 5381
    const saltedGesture = `xueji-gesture:${gesture}:local`
    for (let index = 0; index < saltedGesture.length; index++) {
      hash = (hash * 33) ^ saltedGesture.charCodeAt(index)
    }
    return `gesture_${(hash >>> 0).toString(16)}`
  }
}
