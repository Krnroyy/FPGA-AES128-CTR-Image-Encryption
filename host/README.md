# Laptop UART Receiver

Install dependencies:

```powershell
py -m pip install pyserial pillow
```

Start the receiver before launching the Vitis application:

```powershell
py receive_full_image.py COM11
```

The protocol uses ASCII markers around two 196,608-byte binary payloads:

```text
CIPHERTEXT_BEGIN 196608
<encrypted bytes>
CIPHERTEXT_END
RECOVERED_BEGIN 196608
<recovered bytes>
RECOVERED_END
ZCU104_AES_CTR_DONE
```

