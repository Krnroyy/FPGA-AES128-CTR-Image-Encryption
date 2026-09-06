# Host Tools

The final authenticated-encryption utilities are under `gcm/`.

- `send_receive_gcm_image.py`: one dynamic image, independent Python AESGCM comparison and tamper test.
- `benchmark_gcm_images.py`: multi-image dataset session, CSV/JSON export and same-image/different-IV sensitivity measurement.

Install dependencies with:

```powershell
py -m pip install -r gcm\requirements.txt
```

The earlier `receive_full_image.py` is retained only for the original fixed-image AXI4-Lite baseline.
