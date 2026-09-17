export const AGC_VERIFY_CODE_WRONG: number = 203818130
export const AGC_VERIFY_CODE_EXPIRED: number = 203818129
export const AGC_ALREADY_SIGNED_IN: number = 5

export function mapVerificationCodeErrorMessage(errorCode: number, fallback: string = '验证码验证失败'): string {
  if (errorCode === AGC_VERIFY_CODE_WRONG) {
    return '验证码错误'
  }
  if (errorCode === AGC_VERIFY_CODE_EXPIRED) {
    return '验证码已过期，请重新获取'
  }
  if (errorCode === AGC_ALREADY_SIGNED_IN) {
    return '账号状态已刷新，请重新获取验证码后再试'
  }
  return fallback
}
