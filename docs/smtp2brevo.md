# smtp2brevo Mail Relay / 邮件中转

[中文](#zh-cn) | [English](#english)

<a id="zh-cn"></a>

## 中文

`smtp2brevo` 是一个小型 SMTP 到 Brevo API 的中转服务。

它的用途是解决某些 VPS 服务商封锁 SMTP 出站端口的问题。Sub2API 仍然通过 SMTP 发送邮件，但 `smtp2brevo` 会把邮件转换成 Brevo HTTPS API 请求。

### 工作流程

```text
Sub2API
  -> smtp2brevo
  -> Brevo HTTPS API
  -> 用户邮箱
```

### 需要准备

在 Brevo 中完成：

1. 验证发信域名
2. 配置 SPF、DKIM、DMARC
3. 添加并验证发件人邮箱
4. 生成 Brevo API Key

### 环境变量

复制模板：

```bash
cp .smtp2brevo.env.example .smtp2brevo.env
```

示例：

```env
BREVO_API_KEY=CHANGE_ME
FROM_EMAIL=noreply@example.com
FROM_NAME=Sub2API
REPLY_TO=support@example.com
SMTP_PORT=8025
SMTP_AUTH_USER=sub2api
SMTP_AUTH_PASS=CHANGE_ME
```

### TLS 模式

如果 Sub2API 在 SMTP 认证时要求 TLS，建议使用真实证书。

常见做法：

1. 创建一个域名，例如 `smtp.example.com`
2. 为该域名申请 Let's Encrypt 证书
3. 将证书挂载到 `smtp2brevo` 容器
4. 让 Sub2API 在 Docker 内网中把该域名解析到 `smtp2brevo` 容器

### 安全建议

- 不要把 8025 端口暴露到公网
- 不要提交 `.smtp2brevo.env`
- 如果 `SMTP_AUTH_PASS` 泄露，立即轮换
- 如果 `BREVO_API_KEY` 泄露，立即轮换

---

<a id="english"></a>

## English

`smtp2brevo` is a small SMTP-to-Brevo API relay.

It is useful when a VPS provider blocks outbound SMTP ports. Sub2API still sends mail through SMTP, while `smtp2brevo` converts the message into a Brevo HTTPS API request.

### Flow

```text
Sub2API
  -> smtp2brevo
  -> Brevo HTTPS API
  -> User inbox
```

### Requirements

In Brevo, prepare:

1. Verified sending domain
2. SPF, DKIM, and DMARC records
3. Verified sender email address
4. Brevo API key

### Environment

Copy the template:

```bash
cp .smtp2brevo.env.example .smtp2brevo.env
```

Example:

```env
BREVO_API_KEY=CHANGE_ME
FROM_EMAIL=noreply@example.com
FROM_NAME=Sub2API
REPLY_TO=support@example.com
SMTP_PORT=8025
SMTP_AUTH_USER=sub2api
SMTP_AUTH_PASS=CHANGE_ME
```

### TLS Mode

If Sub2API requires TLS for SMTP authentication, use a real certificate.

A common pattern:

1. Create a hostname such as `smtp.example.com`
2. Issue a Let's Encrypt certificate for it
3. Mount the certificate into the `smtp2brevo` container
4. Make Sub2API resolve that hostname to the `smtp2brevo` container inside Docker

### Security

- Do not expose port 8025 to the public internet
- Do not commit `.smtp2brevo.env`
- Rotate `SMTP_AUTH_PASS` if leaked
- Rotate `BREVO_API_KEY` if leaked
