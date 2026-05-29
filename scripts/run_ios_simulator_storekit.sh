#!/usr/bin/env bash
# StoreKit Configuration (Products.storekit) ile simülatörde çalıştırır.
# flutter run bazen StoreKit dosyasını bağlamaz; bu script Xcode scheme'i kullanır.
set -euo pipefail
cd "$(dirname "$0")/../ios"

echo "→ StoreKit: ios/Products.storekit (Scheme: Runner)"
echo "→ Simülatörde uygulamayı Xcode üzerinden başlatılıyor..."

open Runner.xcworkspace

echo ""
echo "Xcode'da:"
echo "  1. Product → Scheme → Edit Scheme → Run → Options"
echo "  2. StoreKit Configuration = Products.storekit (seçili olmalı)"
echo "  3. Bir iOS Simulator seçin ve Run (▶) basın"
echo ""
echo "Alternatif terminal:"
echo "  cd $(dirname "$0")/.. && flutter clean && flutter run"
