<script>
export default {
  props: {
    socialProfiles: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      socialMediaLinks: [
        {
          key: 'facebook',
          label: 'Facebook',
          icon: 'i-lucide-facebook',
          link: 'https://facebook.com/',
        },
        {
          key: 'twitter',
          label: 'X',
          icon: 'i-woot-x',
          link: 'https://twitter.com/',
        },
        {
          key: 'linkedin',
          label: 'LinkedIn',
          icon: 'i-lucide-linkedin',
          link: 'https://linkedin.com/',
        },
        {
          key: 'github',
          label: 'GitHub',
          icon: 'i-lucide-github',
          link: 'https://github.com/',
        },
        {
          key: 'instagram',
          label: 'Instagram',
          icon: 'i-woot-instagram',
          link: 'https://instagram.com/',
        },
        {
          key: 'telegram',
          label: 'Telegram',
          icon: 'i-woot-telegram',
          link: 'https://t.me/',
        },
        {
          key: 'tiktok',
          label: 'TikTok',
          icon: 'i-woot-tiktok',
          link: 'https://tiktok.com/@',
        },
      ],
    };
  },
  computed: {
    availableProfiles() {
      return this.socialMediaLinks.filter(
        mediaLink => !!this.socialProfiles[mediaLink.key]
      );
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="availableProfiles.length"
    class="my-1 flex flex-wrap items-center gap-1.5"
  >
    <a
      v-for="profile in availableProfiles"
      :key="profile.key"
      :href="`${profile.link}${socialProfiles[profile.key]}`"
      target="_blank"
      rel="noopener noreferrer nofollow"
      class="inline-flex size-9 items-center justify-center rounded-lg bg-ds-bg-sunken text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      :aria-label="`${profile.label}: ${socialProfiles[profile.key]}`"
      :title="profile.label"
    >
      <span class="size-4" :class="profile.icon" aria-hidden="true" />
    </a>
  </div>
</template>
