## ADDED Requirements

### Requirement: 明确的 Debug 删除授权跨重启保留

Debug App MUST 默认禁用真实照片删除；明确开启后 MUST 在本地保存授权，并在无额外参数的后续启动继续允许进入真实删除流程。授权 MUST NOT 跳过复核、二次确认或系统 Photos 确认。

#### Scenario: 开启后从桌面重开
- **WHEN** 用户明确授权通过参数或环境变量开启真实删除，随后无参数重启
- **THEN** 删除授权必须继续有效，无需再次连接电脑开启

#### Scenario: 新安装没有授权
- **WHEN** Debug App 没有已保存授权且没有显式开启参数
- **THEN** 真实删除必须保持禁用

### Requirement: 显式禁删优先并撤销持久授权

显式禁删参数或环境变量 MUST 优先于已保存授权及开启参数，并撤销已保存授权。Release MUST 保持原有行为且不读写 Debug 持久授权。自动化 MUST 继续默认显式禁删。

#### Scenario: 对已开启设备执行安全启动
- **WHEN** 存在持久授权且使用显式禁删启动
- **THEN** 当前启动必须禁删，后续无参数 Debug 启动也必须禁删

#### Scenario: 同时开启与禁用
- **WHEN** 开启及禁删配置同时存在
- **THEN** 禁删必须优先且不得保存开启授权

#### Scenario: Release 启动
- **WHEN** Release App 启动
- **THEN** 默认允许用户确认后的删除，显式禁删仍生效，Debug 偏好不被读取或修改
