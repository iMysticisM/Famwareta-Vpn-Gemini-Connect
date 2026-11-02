# راهنمای اتصال پنل 3X-UI / X-UI به استخر FamVpnGemini

در پنل‌های سری X-UI (مانند 3X-UI یا alireza0 / MHSanaei)، می‌توانید خروجی لوکال FamVpnGemini را به سادگی به عنوان Outbound تعریف کنید.

---

## مرحله ۱: افزودن Outbound به تنظیمات Xray
۱. وارد پنل 3X-UI شوید و به منوی **Xray Settings (تنظیمات هسته)** بروید.
۲. در بخش **Outbounds (خروجی‌ها)**، خروجی جدید زیر را اضافه کنید:

```json
{
  "tag": "FAMVPN-CLEAN",
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

## مرحله ۲: تعریف رول‌های مسیریابی (Routing Rules)
در تب **Routing Rules**، یک قانون جدید ایجاد کنید:
- **Outbound Tag:** `FAMVPN-CLEAN`
- **Domain:** `geosite:openai, geosite:paypal, domain:stripe.com, domain:claude.ai`
*(یا اینباند مربوط به کانفیگ VIP مورد نظرتان را انتخاب کنید).*

۳. دکمه **Save & Restart Xray** را بزنید.
از این پس کانفیگ یا دامنه‌های تعریف شده با IP مسکونی و ضد نشت FamVpnGemini متصل می‌شوند.
