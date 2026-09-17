let myHandler = async function(event, context) {
    // 1. 准备工作
    context.logger.info("=== 开始处理短信发送请求 ===");
    
    try {
        // 2. 解析 AGC 传过来的数据
        // 注意：event.body 是个 JSON 字符串，必须 parse
        let body;
        if (typeof event.body === 'string') {
            body = JSON.parse(event.body);
        } else {
            body = event.body;
        }

        const phoneNumber = body.phoneNumber; // 目标手机号
        const verifyCode = body.verifyCode;   // AGC 生成的 6 位验证码

        // 3. 【核心步骤】打印日志
        // 这行日志会出现在 AGC 后台，你只要看到这行就能知道验证码是多少
        context.logger.info("------------------------------------------------");
        context.logger.info(`【测试模式】 手机号: ${phoneNumber}`);
        context.logger.info(`【测试模式】 验证码: ${verifyCode}  <--- 填这个进 APP`);
        context.logger.info("------------------------------------------------");

        // 4. 告诉 AGC 发送成功
        // 必须返回 code: 200，否则 AGC 认为发送失败会报错
        return {
            "code": 200,
            "message": "模拟发送成功"
        };

    } catch (error) {
        context.logger.error("解析错误: " + error);
        return {
            "code": 500,
            "message": "内部错误"
        };
    }
};

module.exports.myHandler = myHandler;