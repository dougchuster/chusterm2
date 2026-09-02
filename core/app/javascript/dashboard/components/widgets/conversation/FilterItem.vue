<script>
export default {
  props: {
    selectedValue: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
    pathPrefix: {
      type: String,
      required: true,
    },
  },
  emits: ['onChangeFilter'],
  data() {
    return {
      activeValue: this.selectedValue,
    };
  },
  methods: {
    onTabChange() {
      if (this.type === 'status') {
        this.$store.dispatch('setChatStatusFilter', this.activeValue);
      } else {
        this.$store.dispatch('setChatSortFilter', this.activeValue);
      }
      this.$emit('onChangeFilter', this.activeValue, this.type);
    },
  },
};
</script>

<template>
  <select
    v-model="activeValue"
    :aria-label="type"
    class="mx-1 my-0 h-7 w-32 rounded-lg border border-ds-border-subtle bg-ds-bg-sunken py-0 pl-2 pr-7 text-xs font-medium text-ds-fg-default outline-none transition-shadow focus:border-ds-border-focus focus:ring-2 focus:ring-ds-border-focus/30"
    @change="onTabChange()"
  >
    <option v-for="value in items" :key="value" :value="value">
      {{ $t(`${pathPrefix}.${value}.TEXT`) }}
    </option>
  </select>
</template>
