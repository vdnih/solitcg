# 🗺️ TCG風ソリティアゲーム "solitcg" インフラアーキテクチャ設計書 (v1.0)

## 1\. 概要

本ドキュメントは、Flutterで開発する「TCG風ソリティアゲーム (solitcg)」のバックエンドインフラのアーキテクチャを定義するものです。
本アプリは、Googleアカウントによるシングルサインオン、ゲーム進行データ（デッキ・スコア等）の保存、およびWebブラウザでのプレイを主眼としたホスティング機能を持ちます。インフラ構築・管理コストを最小化し、かつWeb版での快適な動作を実現するため、Firebase (BaaS) を全面的に採用します。

## 2\. アーキテクチャ概要

クライアント（Flutterアプリ）とFirebase各サービスが直接通信する「サーバーレスアーキテクチャ」を採用します。
Web版でのパフォーマンスを重視し、バックエンドロジック（Cloud Functions）は初期リリースでは採用せず、クライアントサイドでの処理完結を基本とします。

### 主要コンポーネント

  * **クライアント (Client)**
      * **Flutter Web (Main)**: `CanvasKit` レンダラーを使用し、ブラウザ上でネイティブアプリに近い描画パフォーマンスを実現します。
      * **Flutter Mobile (iOS / Android)**: 将来的な展開を見据え、共通コードベースで管理します。
  * **バックエンド (Firebase)**
      * **Firebase Authentication**: Googleログインによる認証基盤。
      * **Cloud Firestore**: プレイヤーデータおよびゲームマスターデータの管理。
      * **Cloud Storage for Firebase**: カード画像アセットやユーザーアイコンの保存。
      * **Firebase Hosting**: Webゲームの公開・配信（CDN）。

## 3\. 使用サービス詳細

### 3.1. Firebase Authentication (認証)

  * **目的**: プレイヤーの本人確認およびセーブデータの紐付け。
  * **利用プロバイダ**: **Google Sign-In** のみ
      * *理由*: ゲーム開始時の入力ハードルを下げ、かつパスワード忘れ等のサポートコストを排除するため。
  * **連携**: 発行される `uid` を、DBおよびStorageのルートキーとして使用し、データの所有権を明確化します。

### 3.2. Cloud Firestore (データベース)

  * **目的**: ユーザーの所持カード、デッキ構成、戦績データの永続化。
  * **ロケーション**: `asia-northeast1` (東京)
  * **データモデル (Sub-collection pattern)**:
    ユーザーごとのデータを隔離し、セキュリティルールを単純化する構成を採用します。
    ```
    users/{userId}
       ├ stats/summary        (ランク、勝率、通貨などの基本情報)
       ├ decks/{deckId}       (構築済みデッキ情報)
       │   └ cardList: List<String>
       └ history/{matchId}    (対戦・プレイ履歴)
    ```

### 3.3. Cloud Storage for Firebase (ストレージ)

  * **目的**: カードイラストなどの静的アセット、およびユーザーアバター画像の保存。
  * **ロケーション**: `asia-northeast1` (東京)
  * **Web対応 (CORS)**: Web版から画像を取得するため、バケットに対して **CORS (Cross-Origin Resource Sharing)** 設定を適用します。
  * **フォルダ構成**:
    ```
    assets/cards/{cardId}.png  (全ユーザー共有/ReadOnly)
    users/{userId}/avatar.png  (ユーザー固有)
    ```

### 3.4. Firebase Hosting (ホスティング)

  * **目的**: ゲーム本体（Flutter Webアプリ）の公開。
  * **ビルド設定**: ゲームの描画性能を優先するため、`flutter build web --web-renderer canvaskit` を標準ビルドコマンドとします。

## 4\. セキュリティ設計 (Security Rules)

「Deny-by-default（原則拒否）」を採用し、データの改ざんを防ぎます。

### 4.1. Firestore ルール

  * **スコープ**: `users/{userId}` 配下は本人のみ読み書き可能。
  * **共有データ**: マスターデータ等は読み取り専用とします。

<!-- end list -->

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーデータ: 本人のみフルアクセス
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // マスターデータ (例: カード一覧): 認証済みユーザーなら読み取り可能
    match /master_data/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // 管理者のみ (Console経由等)
    }
  }
}
```

### 4.2. Storage ルール

  * **スコープ**:
      * `users/{userId}`: 本人のみ読み書き可。
      * `assets/`: 全員読み取り可（書き込み不可）。

<!-- end list -->

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    
    // ユーザー個別領域
    match /users/{userId}/{allPaths=**} {
      allow read, write: if isOwner(userId);
    }
    
    // ゲームアセット領域 (Web公開用)
    match /assets/{allPaths=**} {
      allow read: if true; // 公開アセット
      allow write: if false;
    }
  }
}
```

## 5\. 運用・管理

  * **デプロイ**:
      * ゲーム本体: `firebase deploy --only hosting`
      * ルール更新: `firebase deploy --only firestore:rules,storage:rules`
  * **CORS設定管理**: Google Cloud Console (Cloud Shell) にて `gsutil` コマンドを用いて管理。

## 6\. リスク対策と既知の制限事項

### 6.1. チート対策 (Client-Side Logic Limitation)

本アーキテクチャはサーバーレスであり、ゲームロジック（勝敗判定など）をクライアントで行います。

  * **リスク**: 知識のあるユーザーによるスコア改ざんや、不正なデッキデータの送信が可能。
  * **許容理由**: 個人開発の規模であり、PvP（リアルタイム対人戦）を主軸としないソリティア型ゲームであるため、厳密なサーバーサイドバリデーションのコストを削減します。

### 6.2. データの不整合

旅行記録アプリ同様、Firestoreのユーザーデータを削除してもStorageの画像（アバター等）は自動削除されません。

  * **対策**: 容量コストへの影響が軽微なため、現状は許容します。