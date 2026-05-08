<script>
export default {
  props: {
    headerTitle: { type: String, default: '' },
    headerContent: { type: String, default: '' },
  },
};
</script>

<template>
  <div class="settings-subpage-header mb-4 w-full">
    <span class="settings-subpage-header__eyebrow">
      Configura&ccedil;&atilde;o guiada
    </span>
    <div class="mt-2 flex min-w-0 items-center gap-3">
      <span class="settings-subpage-header__icon i-lucide-settings-2" />
      <h2 class="settings-subpage-header__title break-words text-n-slate-12">
        {{ headerTitle }}
      </h2>
    </div>
    <p
      v-dompurify-html="headerContent"
      class="settings-subpage-header__content text-body-main w-full text-n-slate-11"
    />
  </div>
</template>

<style scoped>
.settings-subpage-header {
  position: relative;
  overflow: hidden;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 12px;
  padding: 1rem;
  background: rgb(var(--bg-card));
  box-shadow: 0 12px 34px rgba(var(--shell-shadow));
}

.settings-subpage-header::before {
  display: none;
}

.settings-subpage-header__eyebrow {
  display: inline-flex;
  align-items: center;
  border-radius: 9999px;
  border: 1px solid rgb(var(--border-weak));
  padding: 0.3rem 0.65rem;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: uppercase;
  color: rgb(var(--slate-11));
  background: rgb(var(--surface-2));
}

.settings-subpage-header__title {
  margin: 0;
  font-family: Manrope, sans-serif;
  font-size: clamp(1.2rem, 1.6vw, 1.65rem);
  font-weight: 700;
  line-height: 1.08;
}

.settings-subpage-header__icon {
  display: inline-flex;
  width: 2.25rem;
  height: 2.25rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 10px;
  background: rgb(var(--surface-2));
  color: rgb(var(--slate-12));
}

.settings-subpage-header__content {
  position: relative;
  z-index: 1;
  margin: 0.65rem 0 0;
  max-width: 56rem;
  line-height: 1.8;
}
</style>
