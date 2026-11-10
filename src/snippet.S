/*
 * snippet.S —— 三个 gadget（ret_gadget / hit_gadget / ind_gadget）
 *
 * 来源：对话版《L1-1_交接简报》§9.1，标注"上游 vusec/bhi-spectre-bhb 未改，全文"。
 * ⚠️ 移植后请用服务器上的实际文件 `diff` 核验一次，以权威文件为准。
 *   diff <(sed -e 's/[[:space:]]*$//' snippet.S) \
 *        <(ssh <user>@8.137.179.142 'sed -e "s/[[:space:]]*$//" ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force/src/snippet.S')
 */
.text
.global ret_gadget
ret_gadget:
    nop
    ret

.global hit_gadget
.align 10
hit_gadget:
    ldr     x1, [x1]      // 泄露/到达探针：把 x1(=fr_buf) 拉进 L1D
    ret

.global ind_gadget
.align 10
ind_gadget:
    ldr     x0, [x0]      // 从 ftable 载入目标（flush 后此 load 慢→窗口宽）
    br      x0            // 受害者间接分支
