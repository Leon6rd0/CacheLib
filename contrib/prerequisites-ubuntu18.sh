#!/bin/sh
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

return 0
# NOTE:
# GoogleTest/GoogleMock libraries are available in Ubuntu as
# Standard packages, but the do not contain the required CMAKE
# files, and aren't detected when building CacheLib.
# So on Ubuntu-18 - build googletest from source.
### googletest libgtest-dev google-mock
