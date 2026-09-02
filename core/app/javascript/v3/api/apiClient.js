import axios from 'axios';

const { apiHost = '' } = window.chustermConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
