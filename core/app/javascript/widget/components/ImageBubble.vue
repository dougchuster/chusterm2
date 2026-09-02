<script>
export default {
  props: {
    url: { type: String, default: '' },
    thumb: { type: String, default: '' },
    readableTime: { type: String, default: '' },
  },
  emits: ['error'],
  methods: {
    onImgError() {
      this.$emit('error');
    },
  },
};
</script>

<template>
  <a
    :href="url"
    target="_blank"
    rel="noreferrer noopener nofollow"
    class="image"
  >
    <div class="wrap">
      <img :src="thumb" alt="Picture message" @error="onImgError" />
      <span class="time">{{ readableTime }}</span>
    </div>
  </a>
</template>

<style lang="scss" scoped>
.image {
  display: block;

  .wrap {
    position: relative;
    display: flex;
    max-width: 100%;

    &::before {
      background-color: rgb(15 23 42 / 70%);
      bottom: 0;
      content: '';
      height: 1.5rem;
      left: 0;
      opacity: 0.8;
      position: absolute;
      width: 100%;
    }
  }

  img {
    width: 100%;
    max-width: 250px;
  }

  .time {
    @apply text-xs bottom-1 text-white ltr:right-3 rtl:left-3 whitespace-nowrap absolute;
  }
}
</style>
