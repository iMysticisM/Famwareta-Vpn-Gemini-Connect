# راهنمای اتصال مرزبان (Marzban) به استخر FamVpnGemini

برای استفاده از خروجی تمیز FamVpnGemini در پنل مرزبان (Marzban)، کافیست اوت‌باند SOCKS5 را به کانفیگ هسته Xray اضافه کنید.

---

## مرحله ۱: افزودن اوت‌باند در مرزبان
۱. وارد داشبورد مرزبان شوید و به منوی **Core Settings (تنظیمات هسته)** بروید.
۲. در بخش `outbounds`، این بلوک را به ابتدای لیست اوت‌باندها اضافه کنید:

```json
{
  "tag": "FAMVPN-CLEAN-IP",
  "protocol": "socks",
  "settings": {
    "servers": [
      {
        "address": "127.0.0.1",
        "port": 10810
      }
    ]
  }
}
```

---

## مرحله ۲: تعریف روتینگ (قوانین هدایت ترافیک)
در بخش `routing` -> `rules`:

### حالت الف (هدایت سایت‌های حساس، هوش مصنوعی و بانک‌ها به FamVpnGemini):
```json
{
  "type": "field",
  "domain": [
    "domain:openai.com",
    "domain:chatgpt.com",
    "domain:claude.ai",
    "domain:paypal.com",
    "domain:stripe.com"
  ],
  "outboundTag": "FAMVPN-CLEAN-IP"
}
```

### حالت ب (هدایت یک اینباند خاص، مثلاً کانفیگ VIP به FamVpnGemini):
```json
{
  "type": "field",
  "inboundTag": [
    "VLESS REALITY VIP"
  ],
  "outboundTag": "FAMVPN-CLEAN-IP"
}
```

۳. دکمه **Restart Core (راه‌اندازی مجدد هسته)** را در مرزبان بزنید.
تمام شد! اکنون ترافیک اینباند یا دامنه‌های مشخص شده از استخر تمیز FamVpnGemini عبور می‌کند.
