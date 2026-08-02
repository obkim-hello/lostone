# Lostone - Git 分支保护规则

## main 分支保护

**规则**：所有到 main 分支的变更必须通过 Pull Request。

### 保护措施

1. **禁止直接推送**
   - 不允许直接 `git push origin main`
   - 必须从 feature/bugfix/docs 分支创建 PR

2. **PR 审查要求**
   - 至少 1 人 approve
   - 通过所有自动化测试（待配置）
   - 无冲突
   - 符合代码规范

3. **分支合并**
   - 使用 Squash and Merge（推荐）
   - 自动删除已合并的分支

### 工作流程

```
1. 创建 feature 分支
   git checkout -b feature/PRD-002-data-import

2. 编写代码/文档
   git add .
   git commit -m "feat(data-import): 实现微信解析器"

3. 推送分支
   git push origin feature/PRD-002-data-import

4. 创建 Pull Request
   gh pr create --title "[PRD-002] 实现数据导入模块"

5. 代码审查
   - 团队成员 review
   - 提出修改建议
   - approve PR

6. 合并到 main
   - 确保所有检查通过
   - Squash and Merge
   - 自动删除 feature 分支
```

### 分支策略

```
main (受保护)
  ↑
  └── develop (开发集成分支)
        ↑
        ├── feature/PRD-002-data-import
        ├── feature/PRD-003-persona-generation
        ├── bugfix/fix-parser-error
        └── docs/update-readme
```

### 配置方式（GitHub）

在仓库设置中配置：

1. **Settings → Branches → Add rule**
   - Branch name pattern: `main`
   - ☑️ Require a pull request before merging
     - ☑️ Require approvals: 1
   - ☑️ Require status checks to pass before merging
     - （后续添加 CI 检查）
   - ☑️ Do not allow bypassing the above settings

2. **Settings → General**
   - ☑️ Automatically delete head branches

---

> 此规则从现在开始执行，确保代码质量和可追溯性。